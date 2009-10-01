//
// AquaticPrime.c
// AquaticPrime Carbon Implementation
//
// Copyright (c) 2005, Lucas Newman
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//  -Redistributions of source code must retain the above copyright notice,
//   this list of conditions and the following disclaimer.
//  -Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation and/or
//   other materials provided with the distribution.
//  -Neither the name of the Aquatic nor the names of its contributors may be used to 
//   endorse or promote products derived from this software without specific prior written permission.
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

static RSA *rsaKey;
static CFStringRef hash;
static CFMutableArrayRef blacklist;

Boolean APSetKey(CFStringRef key)
{
    hash = CFSTR("");
    blacklist = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    
    // Create a new key
    rsaKey = RSA_new();
    
    // Public exponent is always 3
    BN_hex2bn(&rsaKey->e, "3");
    
    CFMutableStringRef mutableKey = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, key);
    if (!mutableKey)
        return FALSE;
    
    unsigned int maximumCStringLength = CFStringGetMaximumSizeForEncoding(CFStringGetLength(mutableKey), kCFStringEncodingMacRoman) + 1;
    char *keyCStringBuffer = malloc(maximumCStringLength);
    
    // Determine if we have a hex or decimal key
    CFStringLowercase(mutableKey, NULL);
    if (CFStringHasPrefix(mutableKey, CFSTR("0x"))) {
        CFStringTrim(mutableKey, CFSTR("0x"));
        CFStringGetCString(mutableKey, keyCStringBuffer, maximumCStringLength, kCFStringEncodingMacRoman);
        BN_hex2bn(&rsaKey->n, keyCStringBuffer);
    }
    else {
        CFStringGetCString(mutableKey, keyCStringBuffer, maximumCStringLength, kCFStringEncodingMacRoman);
        BN_dec2bn(&rsaKey->n, keyCStringBuffer);
    }
    CFRelease(mutableKey);
    free(keyCStringBuffer);
    
    return TRUE;
}

CFStringRef APHash(void)
{
    return CFStringCreateCopy(kCFAllocatorDefault, hash);
}

void APSetHash(CFStringRef newHash)
{
    if (hash != NULL)
        CFRelease(hash);
    hash = CFStringCreateCopy(kCFAllocatorDefault, newHash);
}

// Set the entire blacklist array, removing any existing entries
void APSetBlacklist(CFArrayRef hashArray)
{
    if (blacklist != NULL)
        CFRelease(blacklist);
    blacklist = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, hashArray);
}

// Add a single entry to the blacklist-- provided because CFArray doesn't have an equivalent
// for NSArray's +arrayWithObjects, which means it may be easier to pass blacklist entries
// one at a time rather than building an array first and passing the whole thing.
void APBlacklistAdd(CFStringRef blacklistEntry)
{
    CFArrayAppendValue(blacklist, blacklistEntry);
}

CFDictionaryRef APCreateDictionaryForLicenseData(CFDataRef data)
{
    if (!rsaKey->n || !rsaKey->e)
        return NULL;
    
    // Make the property list from the data
    CFStringRef errorString = NULL;
    CFPropertyListRef propertyList;
    propertyList = CFPropertyListCreateFromXMLData(kCFAllocatorDefault, data, kCFPropertyListMutableContainers, &errorString);
    if (errorString || CFDictionaryGetTypeID() != CFGetTypeID(propertyList) || !CFPropertyListIsValid(propertyList, kCFPropertyListXMLFormat_v1_0)) {
        if (propertyList)
            CFRelease(propertyList);
        return NULL;
    }
    
    // Load the signature
    CFMutableDictionaryRef licenseDictionary = (CFMutableDictionaryRef)propertyList;
    if (!CFDictionaryContainsKey(licenseDictionary, CFSTR("Signature"))) {
        CFRelease(licenseDictionary);
        return NULL;
    }
    
    unsigned char sigBytes[128];
    CFDataRef sigData = CFDictionaryGetValue(licenseDictionary, CFSTR("Signature"));
    CFDataGetBytes(sigData, CFRangeMake(0, CFDataGetLength(sigData)), sigBytes);
    CFDictionaryRemoveValue(licenseDictionary, CFSTR("Signature"));
    
    // Decrypt the signature
    unsigned char checkDigest[128] = {0};
    if (RSA_public_decrypt(CFDataGetLength(sigData), sigBytes, checkDigest, rsaKey, RSA_PKCS1_PADDING) != SHA_DIGEST_LENGTH) {
        CFRelease(licenseDictionary);
        return NULL;
    }
    
    // Get the license hash
    CFMutableStringRef hashCheck = CFStringCreateMutable(kCFAllocatorDefault,0);
    int hashIndex;
    for (hashIndex = 0; hashIndex < SHA_DIGEST_LENGTH; hashIndex++)
        CFStringAppendFormat(hashCheck, NULL, CFSTR("%02x"), checkDigest[hashIndex]);
    APSetHash(hashCheck);
    CFRelease(hashCheck);
    
    if (blacklist && (CFArrayContainsValue(blacklist, CFRangeMake(0, CFArrayGetCount(blacklist)), hash) == true))
        return NULL;
    
    // Get the number of elements
    CFIndex count = CFDictionaryGetCount(licenseDictionary);
    // Load the keys and build up the key array
    CFMutableArrayRef keyArray = CFArrayCreateMutable(kCFAllocatorDefault, count, NULL);
    CFStringRef keys[count];
    CFDictionaryGetKeysAndValues(licenseDictionary, (const void**)&keys, NULL);
    int i;
    for (i = 0; i < count; i++)
        CFArrayAppendValue(keyArray, keys[i]);
    
    // Sort the array
    int context = kCFCompareCaseInsensitive;
    CFArraySortValues(keyArray, CFRangeMake(0, count), (CFComparatorFunction)CFStringCompare, &context);
    
    // Setup up the hash context
    SHA_CTX ctx;
    SHA1_Init(&ctx);
    // Convert into UTF8 strings
    for (i = 0; i < count; i++)
    {
        char *valueBytes;
        int valueLengthAsUTF8;
        CFStringRef key = CFArrayGetValueAtIndex(keyArray, i);
        CFStringRef value = CFDictionaryGetValue(licenseDictionary, key);
        
        // Account for the null terminator
        valueLengthAsUTF8 = CFStringGetMaximumSizeForEncoding(CFStringGetLength(value), kCFStringEncodingUTF8) + 1;
        valueBytes = (char *)malloc(valueLengthAsUTF8);
        CFStringGetCString(value, valueBytes, valueLengthAsUTF8, kCFStringEncodingUTF8);
        SHA1_Update(&ctx, valueBytes, strlen(valueBytes));
        free(valueBytes);
    }
    unsigned char digest[SHA_DIGEST_LENGTH];
    SHA1_Final(digest, &ctx);
    
    if (keyArray != NULL)
        CFRelease(keyArray);
    
    // Check if the signature is a match    
    for (i = 0; i < SHA_DIGEST_LENGTH; i++) {
        if (checkDigest[i] ^ digest[i]) {
            CFRelease(licenseDictionary);
            return NULL;
        }
    }
    
    // If it's a match, we return the dictionary; otherwise, we never reach this
    return licenseDictionary;
}

CFDictionaryRef APCreateDictionaryForLicenseFile(CFURLRef path)
{
    // Read the XML file
    CFDataRef data;
    SInt32 errorCode;
    Boolean status;
    status = CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, path, &data, NULL, NULL, &errorCode);
    
    if (errorCode || status != true)
        return NULL;
    
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseData(data);
    CFRelease(data);
    return licenseDictionary;
}

Boolean APVerifyLicenseData(CFDataRef data)
{
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseData(data);
    if (licenseDictionary) {
        CFRelease(licenseDictionary);
        return TRUE;
    } else {
        return FALSE;
    }
}

Boolean APVerifyLicenseFile(CFURLRef path)
{
    CFDictionaryRef licenseDictionary = APCreateDictionaryForLicenseFile(path);
    if (licenseDictionary) {
        CFRelease(licenseDictionary);
        return TRUE;
    } else {
        return FALSE;
    }
}
