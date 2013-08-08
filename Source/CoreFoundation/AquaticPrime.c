//
// AquaticPrime.c
// AquaticPrime Core Foundation Implementation
//
// Copyright (c) 2005-2013 Lucas Newman and other contributors
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//  - Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
//  - Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation and/or
//    other materials provided with the distribution.
//  - Neither the name of the Aquatic nor the names of its contributors may be used to
//    endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL 
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER 
// IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT 
// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include "AquaticPrime.h"

#include <Security/Security.h>

#define APFree(x) do { if ((x)) { free((x)); (x) = NULL; } } while (0)
#define APRelease(x) do { if ((x)) { CFRelease((x)); (x) = NULL; } } while(0)
#define APArrayLength(x) (sizeof((x))/sizeof((x)[0]))

static SecKeyRef g_apPublicKey;
static CFMutableArrayRef g_blacklist;

static Boolean APHexDigitStringHasPrefix(CFStringRef hexDigitString)
{
    return (CFStringGetLength(hexDigitString) > 2 && (CFStringHasPrefix(hexDigitString, CFSTR("0x")) || CFStringHasPrefix(hexDigitString, CFSTR("0X"))));
}

static Boolean APIsHexKey(CFStringRef key)
{
    CFStringRef keyWithoutPrefix = APHexDigitStringHasPrefix(key) ? CFStringCreateWithSubstring(kCFAllocatorDefault, key, CFRangeMake(2, CFStringGetLength(key) - 2)) : CFStringCreateCopy(kCFAllocatorDefault, key);

    Boolean isHexKey = (CFStringGetLength(keyWithoutPrefix) == (1024/8*2));

    APRelease(keyWithoutPrefix);

    return isHexKey;
}

static CFDataRef APDataCreateFromHexDigitString(CFStringRef hexDigitString)
{
    CFMutableDataRef mutableData = CFDataCreateMutable(kCFAllocatorDefault, 0);

    CFIndex textLength = CFStringGetLength(hexDigitString);
    if (textLength % 2 == 0)
    {
        CFRange range = APHexDigitStringHasPrefix(hexDigitString) ? CFRangeMake(2, 2) : CFRangeMake(0, 2);

        // Munch through the hex string, taking two characters at a time for each byte to append as the key data
        while (range.location < textLength)
        {
            CFStringRef hexDigitPairString = CFStringCreateWithSubstring(kCFAllocatorDefault, hexDigitString, range);

            char hexDigitPairCString[16] = { 0 };
            if (CFStringGetCString(hexDigitPairString, &(hexDigitPairCString[0]), APArrayLength(hexDigitPairCString), kCFStringEncodingUTF8))
            {
                unsigned int scannedValue = 0;
                if (sscanf(hexDigitPairCString, "%x", &scannedValue))
                {
                    uint8_t byteValue = (uint8_t) scannedValue;
                    CFDataAppendBytes(mutableData, &byteValue, 1);
                }
            }

            APRelease(hexDigitPairString);
            range.location += 2;
        }
    }

    CFDataRef data = CFDataCreateCopy(kCFAllocatorDefault, mutableData);
    APRelease(mutableData);

    return data;
}

static CFStringRef APCreateHexDigitStringFromData(CFDataRef data)
{
    UInt8 const *dataBytes = CFDataGetBytePtr(data);
    CFIndex dataLength = CFDataGetLength(data);

    CFMutableStringRef mutableString = CFStringCreateMutable(kCFAllocatorDefault, 0);

    for (CFIndex dataIndex = 0; dataIndex < dataLength; ++dataIndex)
    {
        CFStringAppendFormat(mutableString, NULL, CFSTR("%02x"), dataBytes[dataIndex]);
    }

    CFStringRef hexDigitString = CFStringCreateCopy(kCFAllocatorDefault, mutableString);
    APRelease(mutableString);

    return hexDigitString;
}

static CFStringRef APPEMKeyCreateFromHexKey(CFStringRef hexKey)
{
    CFStringRef pemKey = NULL;

    // Convert a raw 1024 bit key to a PEM formatted string that includes the headers
    // -----BEGIN RSA PUBLIC KEY-----
    // (base64 ASN1 encoded data here)
    // -----END RSA PUBLIC KEY-----
    uint8_t keyHeader[] = {
            0x30, 0x81, 0x9F,                                                   // SEQUENCE length 0x9F
            0x30, 0x0D,                                                         // SEQUENCE length 0x0D
            0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,   // rsaEncryption, PKCS #1
            0x05, 0x00,                                                         // NULL
            0x03, 0x81, 0x8D, 0x00,                                             // BIT STRING, length 0x8D
            0x30, 0x81, 0x89,                                                   // SEQUENCE length 0x89
            0x02, 0x81, 0x81,                                                   // INTEGER length 0x81
            0x00                                                                // MSB = zero to make sure INTEGER is positively signed
    };

    uint8_t keyFooter[] = {
            0x02, 0x03, 0x00, 0x00, 0x03                                        // INTEGER length 3, value = 0x03 (RSA exponent)
    };

    CFDataRef hexKeyData = APDataCreateFromHexDigitString(hexKey);
    if (hexKeyData)
    {
        CFMutableDataRef keyData = CFDataCreateMutable(kCFAllocatorDefault, 0);

        CFDataAppendBytes(keyData, keyHeader, APArrayLength(keyHeader));
        CFDataAppendBytes(keyData, CFDataGetBytePtr(hexKeyData), CFDataGetLength(hexKeyData));
        CFDataAppendBytes(keyData, keyFooter, APArrayLength(keyFooter));

        APRelease(hexKeyData);

        // Just need to base64 encode this data now and wrap the string in the BEGIN, END RSA PUBLIC KEY
        SecTransformRef encoder = SecEncodeTransformCreate(kSecBase64Encoding, NULL); // Ignoring errors
        if (encoder)
        {
            Boolean result = SecTransformSetAttribute(encoder, kSecTransformInputAttributeName, keyData, NULL); // Ignoring errors
            if (result)
            {
                CFDataRef base64EncodedKeyData = SecTransformExecute(encoder, NULL); // Ignoring errors
                CFStringRef base64EncodedKey = CFStringCreateWithBytes(kCFAllocatorDefault, CFDataGetBytePtr(base64EncodedKeyData), CFDataGetLength(base64EncodedKeyData), kCFStringEncodingUTF8, FALSE);

                CFMutableStringRef mutableKeyString = CFStringCreateMutable(kCFAllocatorDefault, 0);
                CFStringAppend(mutableKeyString, CFSTR("-----BEGIN RSA PUBLIC KEY-----\n"));
                CFStringAppend(mutableKeyString, base64EncodedKey);
                CFStringAppend(mutableKeyString, CFSTR("\n-----END RSA PUBLIC KEY-----"));

                pemKey = CFStringCreateCopy(kCFAllocatorDefault, mutableKeyString);

                APRelease(mutableKeyString);
                APRelease(base64EncodedKey);
                APRelease(base64EncodedKeyData);
            }

            APRelease(encoder);
        }

        APRelease(keyData);
    }

    return pemKey;
}

Boolean APSetKey(CFStringRef newKey)
{
    Boolean result = FALSE;

    // Free any existing key we have a reference to.
    APRelease(g_apPublicKey);

    if (newKey == NULL || CFStringGetLength(newKey) == 0)
    {
        return FALSE;
    }

    // We expect either a raw hex string of 1024 bits (so 128 bytes or string length of 256)
    // ...OR we can use a full PEM encoded key wrapped with the
    // -----BEGIN RSA PUBLIC KEY-----
    // (base64 ASN1 encoded data here)
    // -----END RSA PUBLIC KEY-----
    //
    // If we are supplied with a legacy public key in raw format, we build it into a PEM
    // encoded string that the import function can deal with.

    CFStringRef pemKey = APIsHexKey(newKey) ? APPEMKeyCreateFromHexKey(newKey) : CFStringCreateCopy(kCFAllocatorDefault, newKey);
    CFDataRef keyAsData = CFStringCreateExternalRepresentation(kCFAllocatorDefault, pemKey, kCFStringEncodingUTF8, 0);
    if (keyAsData)
    {
        CFArrayRef outItems = NULL;

        SecExternalItemType itemType = kSecItemTypePublicKey;
        SecExternalFormat externalFormat = kSecFormatPEMSequence;

        // Set the key as extractable. Looking through the source code in SecImportExportUtils.cpp
        // it looks like this isn't handled, yet it seems to be documented to me. One day the code
        // may catch up, so I'm leaving this here to show the intention.
        uint32 keyAttrValue = CSSM_KEYATTR_EXTRACTABLE;
        CFNumberRef value = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &keyAttrValue);
        CFNumberRef values[1] = { value };

        CFArrayRef keyAttributes = CFArrayCreate(kCFAllocatorDefault, (void const **)&values[0], 1, &kCFTypeArrayCallBacks);
        APRelease(value);

        SecItemImportExportKeyParameters params = {
                .version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION,
                .flags = kSecKeyNoAccessControl,
                .passphrase = NULL,
                .alertTitle = NULL,
                .alertPrompt = NULL,
                .accessRef = NULL,
                .keyUsage = NULL,
                .keyAttributes = keyAttributes
        };

        OSStatus osStatus = SecItemImport(keyAsData, NULL, &externalFormat, &itemType, 0, &params, NULL, &outItems);
        if (osStatus == noErr && CFArrayGetCount(outItems) > 0)
        {
            g_apPublicKey = (SecKeyRef)CFArrayGetValueAtIndex(outItems, 0);
            CFRetain(g_apPublicKey);
            
            result = TRUE;
        }

        APRelease(keyAsData);
        APRelease(outItems);
        APRelease(keyAttributes);
    }

    APRelease(pemKey);

    return result;
}

// Set the entire blacklist array, removing any existing entries
void APSetBlacklist(CFArrayRef hashArray)
{
    APRelease(g_blacklist);
    g_blacklist = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, hashArray);
}

// Add a single entry to the blacklist-- provided because CFArray doesn't have an equivalent
// for NSArray's +arrayWithObjects, which means it may be easier to pass blacklist entries
// one at a time rather than building an array first and passing the whole thing.
void APBlacklistAdd(CFStringRef blacklistEntry)
{
    if (g_blacklist == NULL)
    {
        g_blacklist = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    }

    CFArrayAppendValue(g_blacklist, blacklistEntry);
}

static CFComparisonResult APCompareStrings(const void *val1, const void *val2, __unused void *context)
{
    return CFStringCompare(val1, val2, 0);
}

static CFDataRef APCreateHashForDictionary(CFDictionaryRef dict)
{
    CFDataRef hash = NULL;

    // Grab all values from the dictionary
    CFMutableDataRef dictData = CFDataCreateMutable(kCFAllocatorDefault, 0);

    CFIndex keyCount = CFDictionaryGetCount(dict);
    void *keys = malloc(sizeof(CFTypeRef) * (size_t)keyCount);
    CFDictionaryGetKeysAndValues(dict, keys, NULL);

    CFArrayRef keysArray = CFArrayCreate(kCFAllocatorDefault, keys, CFDictionaryGetCount(dict), &kCFTypeArrayCallBacks);
    CFMutableArrayRef sortedKeysArray = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, keysArray);
    APRelease(keysArray);
    APFree(keys);
    
    // Sort the keys so we always have a uniform order
    CFArraySortValues(sortedKeysArray, CFRangeMake(0, CFArrayGetCount(sortedKeysArray)), APCompareStrings, NULL);

    for (CFIndex keyIndex = 0; keyIndex < keyCount; ++keyIndex)
    {
        const void *dictionaryValue = CFDictionaryGetValue(dict, CFArrayGetValueAtIndex(sortedKeysArray, keyIndex));
        if (CFGetTypeID(dictionaryValue) == CFStringGetTypeID())
        {
            CFStringRef dictionaryString = (CFStringRef)dictionaryValue;
            CFIndex bufferSize = 0;
            CFRange stringRange = CFRangeMake(0, CFStringGetLength(dictionaryString));

            if (CFStringGetBytes(dictionaryString, stringRange, kCFStringEncodingUTF8, 0, FALSE, NULL, 0, &bufferSize) > 0)
            {
                UInt8 *stringBuffer = malloc(sizeof(UInt8) * (size_t)bufferSize);
                if (CFStringGetBytes(dictionaryString, stringRange, kCFStringEncodingUTF8, 0, FALSE, stringBuffer, bufferSize, NULL) > 0)
                {
                    CFDataAppendBytes(dictData, stringBuffer, bufferSize);
                }

                APFree(stringBuffer);
            }
        }
    }
    
    APRelease(sortedKeysArray);
    
    // Hash the data
    SecTransformRef hashFunction = SecDigestTransformCreate(kSecDigestSHA1, 0, NULL); // TODO: handle errors
    if (hashFunction)
    {
        Boolean result = SecTransformSetAttribute(hashFunction, kSecTransformInputAttributeName, dictData, NULL); // TODO: handle errors
        if (result)
        {
            hash = SecTransformExecute(hashFunction, NULL); // TODO: handle errors
        }

        APRelease(hashFunction);
    }
    
    APRelease(dictData);

    return hash;
}

static Boolean APBlacklistContainsHashString(CFStringRef hashString)
{
    return g_blacklist && CFArrayContainsValue(g_blacklist, CFRangeMake(0, CFArrayGetCount(g_blacklist)), hashString);
}

CFDictionaryRef APCreateDictionaryForLicenseData(CFDataRef data)
{
    CFDictionaryRef dictionary = NULL;

    if (g_apPublicKey)
    {
        CFPropertyListRef propertyList = CFPropertyListCreateWithData(kCFAllocatorDefault, data, kCFPropertyListMutableContainersAndLeaves, NULL, NULL); // TODO: handle errors
        if (propertyList && CFGetTypeID(propertyList) == CFDictionaryGetTypeID())
        {
            CFStringRef signatureKey = CFSTR("Signature");

            CFMutableDictionaryRef licenseDictionary = (CFMutableDictionaryRef)propertyList;
            CFDataRef signature = CFDictionaryGetValue(licenseDictionary, signatureKey);
            if (signature)
            {
                CFRetain(signature);

                CFDictionaryRemoveValue(licenseDictionary, signatureKey);

                CFDataRef hashData = APCreateHashForDictionary(licenseDictionary);
                CFStringRef hashString = APCreateHexDigitStringFromData(hashData);

                if (APBlacklistContainsHashString(hashString) == FALSE)
                {
                    // Verify the signed hash using the public key, passing the raw hash data as the input
                    SecTransformRef verifyFunction = SecVerifyTransformCreate(g_apPublicKey, signature, NULL); // TODO: handle errors
                    if (verifyFunction)
                    {
                        Boolean result = TRUE;

                        result &= SecTransformSetAttribute(verifyFunction, kSecTransformInputAttributeName, hashData, NULL); // TODO: handle errors
                        result &= SecTransformSetAttribute(verifyFunction, kSecInputIsAttributeName, kSecInputIsRaw, NULL); // TODO: handle errors

                        if (result)
                        {
                            CFTypeRef valid = SecTransformExecute(verifyFunction, NULL); // TODO: handle errors
                            if (CFGetTypeID(valid) == CFBooleanGetTypeID() && CFBooleanGetValue((CFBooleanRef)valid))
                            {
                                dictionary = CFDictionaryCreateCopy(kCFAllocatorDefault, licenseDictionary);
                            }

                            APRelease(valid);
                        }

                        APRelease(verifyFunction);
                    }
                }

                APRelease(hashData);
                APRelease(hashString);
                APRelease(signature);
            }
        }

        APRelease(propertyList);
    }

    return dictionary;
}

CFDictionaryRef APCreateDictionaryForLicenseFile(CFURLRef path)
{
    CFDictionaryRef licenseDictionary = NULL;

    CFDataRef data;
    SInt32 errorCode;
    Boolean status = CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, path, &data, NULL, NULL, &errorCode);

    if (status == TRUE && errorCode == 0)
    {
        licenseDictionary = APCreateDictionaryForLicenseData(data);
    }

    APRelease(data);
    return licenseDictionary;
}

Boolean APVerifyLicenseData(CFDataRef data)
{
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseData(data);
    Boolean result = licenseDictionary != NULL;

    APRelease(licenseDictionary);
    return result;
}

Boolean APVerifyLicenseFile(CFURLRef path)
{
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseFile(path);
    Boolean result = licenseDictionary != NULL;

    APRelease(licenseDictionary);
    return result;
}
