//
// AquaticPrime.h
// AquaticPrime Cocoa + Security Framework Implementation
//
// Copyright (c) 2005-2012 Lucas Newman, Mathew Waters and other contributors
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//    •Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//    •Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation and/or
//     other materials provided with the distribution.
//    •Neither the name of Aquatic nor the names of its contributors may be used to
//     endorse or promote products derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
// FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
// IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#import "AquaticPrime.h"
#import "NSData+hexDigits.h"

@interface AquaticPrime()
@property (nonatomic, assign) SecKeyRef publicKeyRef;
@property (nonatomic, assign) SecKeyRef privateKeyRef;
@property (nonatomic, strong) NSString *aqError;
@property (nonatomic, strong) NSString *cachedPrivateKey; // Because we can't export it once we've imported it
@end

@implementation AquaticPrime

- (id)init {
    return [self initWithKey:nil privateKey:nil];
}

- (id)initWithKey:(NSString *)key {
    return [self initWithKey:key privateKey:nil];
}

- (id)initWithKey:(NSString *)key privateKey:(NSString *)privateKey {
    if (!(self = [super init]))
        return nil;
    
    _publicKeyRef = NULL;
    _privateKeyRef = NULL;
    _aqError = [[NSString alloc] init];
    _hash = [[NSString alloc] init];
    
    [self setKey:key privateKey:privateKey];
    
    return self;
}

- (void)dealloc {
    // Release core foundation objects
    self.publicKeyRef = NULL;
    self.privateKeyRef = NULL;
}

+ (id)aquaticPrimeWithKey:(NSString *)key privateKey:(NSString *)privateKey {
    return [[AquaticPrime alloc] initWithKey:key privateKey:privateKey];
}

+ (id)aquaticPrimeWithKey:(NSString *)key {
    return [[AquaticPrime alloc] initWithKey:key privateKey:nil];
}

- (void)setPrivateKeyRef:(SecKeyRef)privateKeyRef {
    if (privateKeyRef != _privateKeyRef) {
        if (_privateKeyRef != NULL) {
            CFRelease(_privateKeyRef);
        }
        _privateKeyRef = privateKeyRef;
        if (_privateKeyRef != NULL) {
            CFRetain(_privateKeyRef);
        }
        self.cachedPrivateKey = nil;
    }
}

- (void)setPublicKeyRef:(SecKeyRef)publicKeyRef {
    if (publicKeyRef != _publicKeyRef) {
        if (_publicKeyRef != NULL) {
            CFRelease(_publicKeyRef);
        }
        _publicKeyRef = publicKeyRef;
        if (_publicKeyRef != NULL) {
            CFRetain(_publicKeyRef);
        }
    }
}

- (BOOL)setKey:(NSString *)key {
    return [self setKey:key privateKey:nil];
}

- (BOOL)setKey:(NSString *)key privateKey:(NSString *)privateKey {
    // Free any existing keys we have a reference to
    self.publicKeyRef = NULL;
    self.privateKeyRef = NULL;
    
    // Must have public modulus, private key is optional
    if (!key || [key isEqualToString:@""]) {
        [self setAqError:@"Empty public key parameter"];
        return NO;
    }
    
    // We expect either a raw hex string of 1024 bits (so 128 bytes or string length of 256)
    // ...OR we can use a full PEM encoded key wrapped with the
    // -----BEGIN RSA PUBLIC KEY-----
    // (base64 ASN1 encoded data here)
    // -----END RSA PUBLIC KEY-----
    //
    // If we are supplied with a legacy public key in raw format, we build it into a PEM
    // encoded string that the import function can deal with.
    if ([[key lowercaseString] hasPrefix:@"0x"] && [key length] > 2) {
		key = [key substringFromIndex:2];
    }
    if ([key length] == 1024/8*2) {
        key = [self pemKeyFromRawHex:key];
    }

    SecItemImportExportKeyParameters params = {0};
    params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
    params.flags = kSecKeyNoAccessControl;
    SecExternalItemType itemType = kSecItemTypePublicKey;
    SecExternalFormat externalFormat = kSecFormatPEMSequence;
    CFArrayRef temparray = NULL;
    OSStatus oserr = noErr;
    
    // Set the key as extractable. Looking through the source code in SecImportExportUtils.cpp
    // it looks like this isn't handled, yet it seems to be documented to me. One day the code
    // may catch up, so I'm leaving this here to show the intention.
    NSArray *keyAttributes = @[ @(CSSM_KEYATTR_EXTRACTABLE) ];
    params.keyAttributes = (__bridge CFArrayRef)(keyAttributes);
    
    oserr = SecItemImport((__bridge CFDataRef)[key dataUsingEncoding:NSUTF8StringEncoding],
                          NULL,
                          &externalFormat,
                          &itemType,
                          0,
                          &params,
                          NULL,
                          &temparray);
    
    if (oserr != noErr) {
        [self setAqError:[NSString stringWithFormat:@"Failed to import public key (oserr=%ld)", (long)oserr]];
        return NO;
    }
    
    self.publicKeyRef = (SecKeyRef)CFArrayGetValueAtIndex(temparray, 0);
    CFRelease(temparray);
    
    if (privateKey != nil) {
        itemType = kSecItemTypePrivateKey;
        externalFormat = kSecFormatPEMSequence;

        oserr = SecItemImport((__bridge CFDataRef)[privateKey dataUsingEncoding:NSUTF8StringEncoding],
                              NULL,
                              &externalFormat,
                              &itemType,
                              0,
                              &params,
                              NULL,
                              &temparray);
        
        if (oserr != noErr) {
            [self setAqError:[NSString stringWithFormat:@"Failed to import private key (oserr=%ld)", (long)oserr]];
            return NO;
        }
        
        self.privateKeyRef = (SecKeyRef)CFArrayGetValueAtIndex(temparray, 0);
        CFRelease(temparray);
        
        // Since we can't export the key yet, keep a cached copy
        self.cachedPrivateKey = privateKey;
    }
    
    return YES;
}

- (NSString *)pemKeyFromRawHex:(NSString*)key {
    // Convert a raw 1024 bit key to a PEM formatted string that includes the headers
    // -----BEGIN RSA PUBLIC KEY-----
    // (base64 ASN1 encoded data here)
    // -----END RSA PUBLIC KEY-----
    uint8_t raw1[] = {
        0x30, 0x81, 0x9F,                                                   // SEQUENCE length 0x9F
        0x30, 0x0D,                                                         // SEQUENCE length 0x0D
        0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,   // rsaEncryption, PKCS #1
        0x05, 0x00,                                                         // NULL
        0x03, 0x81, 0x8D, 0x00,                                             // BIT STRING, length 0x8D
        0x30, 0x81, 0x89,                                                   // SEQUENCE length 0x89
        0x02, 0x81, 0x81,                                                   // INTEGER length 0x81
        0x00                                                                // MSB = zero to make sure INTEGER is positively signed
    };
    
    uint8_t raw2[] = {
        0x02, 0x03, 0x00, 0x00, 0x03                                        // INTEGER length 3, value = 0x03 (RSA exponent)
    };
    
    NSMutableData *keyData = [NSMutableData data];
    [keyData appendBytes:raw1 length:sizeof(raw1)/sizeof(uint8_t)];
    
    // Munch through the hex string, taking two characters at a time for each byte
    // to append as the key data
    NSData *rawKey = [NSData dataWithHexDigitRepresentation:key];
    if (rawKey == nil) {
        // Failed to import the key (bad hex digit?)
        [self setAqError:@"Bad public key"];
        return nil;
    }
    
    [keyData appendData:rawKey];
    [keyData appendBytes:raw2 length:sizeof(raw2)/sizeof(uint8_t)];
    
    // Just need to base64 encode this data now and wrap the string
    // in the BEGIN, END RSA PUBLIC KEY
    CFErrorRef error = NULL;
    SecTransformRef encoder = SecEncodeTransformCreate(kSecBase64Encoding, &error);
    if (error != NULL) {
        [self setAqError:@"Failed to create base64 encoder"];
        if (encoder) {
            CFRelease(encoder);
        }
        return nil;
    }
    SecTransformSetAttribute(encoder,
                             kSecTransformInputAttributeName,
                             (__bridge CFDataRef)keyData,
                             &error);
    if (error != NULL) {
        CFRelease(encoder);
        [self setAqError:@"Failed to attribute base64 encoder"];
        return nil;
    }
    CFDataRef cfKeyData = SecTransformExecute(encoder, &error);
    key = [[NSString alloc] initWithData:(__bridge NSData*)cfKeyData encoding:NSUTF8StringEncoding];
    CFRelease(cfKeyData);
    CFRelease(encoder);
    
    NSString *beginRsaKey = @"-----BEGIN RSA PUBLIC KEY-----";
    NSString *endRsaKey = @"-----END RSA PUBLIC KEY-----";
    key = [NSString stringWithFormat:@"%@\n%@\n%@", beginRsaKey, key, endRsaKey];
    
    return key;
}

- (NSString *)key {
    // Exports the public key in PEM format (with -----BEGIN RSA PUBLIC KEY----- wrapper)
    // If you require the raw kay bits, it is possible to decode the base64 content,
    // then the ASN.1 formatted data to extract it. Note the RSA exponent is also encoded
    // and while AquaticPrime uses an exponent of 3, this may not be the same for keys
    // generated using this class. Exponent value of 65537 is more likely. If this class
    // is used to generate a key pair, please pass the whole PEM encoded string as the
    // public key when initialising a new instance so it can read the correct exponent.
    if (!self.publicKeyRef) {
        return nil;
    }
    
    SecItemImportExportKeyParameters params = {0};
    params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
    
    NSArray *keyUsage = @[ (id)kSecAttrCanVerify ];
    params.keyUsage = (__bridge CFArrayRef)(keyUsage);
    
    NSArray *keyAttributes = @[];
    params.keyAttributes = (__bridge CFArrayRef)(keyAttributes);
    
    SecExternalFormat externalFormat = kSecFormatPEMSequence;
    CFDataRef pkCfData = NULL;
    OSStatus oserr = noErr;
    
    oserr = SecItemExport(self.publicKeyRef,
                          externalFormat,
                          0,
                          &params,
                          (CFDataRef *)&pkCfData);
    if (oserr != noErr) {
        [self setAqError:[NSString stringWithFormat:@"Failed to export public key (oserr=%ld)", (long)oserr]];
        return nil;
    }
    
    NSData *pkData = (__bridge_transfer NSData*)pkCfData;
    NSString *pkText = [[NSString alloc] initWithData:pkData encoding:NSUTF8StringEncoding];
    return pkText;
}

- (NSString *)privateKey {
    // Exports the private key in PEM format (with -----BEGIN RSA PRIVATE KEY----- wrapper)
    if (!self.privateKeyRef) {
        return nil;
    }
    
    SecItemImportExportKeyParameters params = {0};
    params.version = SEC_KEY_IMPORT_EXPORT_PARAMS_VERSION;
    
    NSArray *keyUsage = @[ (id)kSecAttrCanSign ];
    params.keyUsage = (__bridge CFArrayRef)(keyUsage);
    
    NSArray *keyAttributes = @[ ];
    params.keyAttributes = (__bridge CFArrayRef)(keyAttributes);
    
    SecExternalFormat externalFormat = kSecFormatPEMSequence;
    CFDataRef pkCfData = NULL;
    OSStatus oserr = noErr;
    
    oserr = SecItemExport(self.privateKeyRef,
                          externalFormat,
                          0,
                          &params,
                          (CFDataRef *)&pkCfData);
    if (oserr) {
        // Did we keep a cached copy of the private key?
        [self setAqError:[NSString stringWithFormat:@"Failed to export private key (oserr=%ld)", (long)oserr]];
        return self.cachedPrivateKey;
    }
    
    NSData *pkData = (__bridge_transfer NSData*)pkCfData;
    NSString *pkText = [[NSString alloc] initWithData:pkData encoding:NSUTF8StringEncoding];
    return pkText;
}

- (BOOL)generateKeys {
    self.publicKeyRef = NULL;
    self.privateKeyRef = NULL;
    
    OSStatus oserr = noErr;

    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
                                (id)kSecAttrKeyTypeRSA, (id)kSecAttrKeyType,
                                [NSNumber numberWithInteger:1024], kSecAttrKeySizeInBits,
                                nil];
    oserr = SecKeyGeneratePair((__bridge CFDictionaryRef)parameters, &_publicKeyRef, &_privateKeyRef);
    if (oserr != noErr) {
        return NO;
    }
    return YES;
}

#pragma mark Signing

- (NSData*)computedHashForDictionary:(NSDictionary*)dict {
    // Grab all values from the dictionary
    NSMutableArray *keyArray = [NSMutableArray arrayWithArray:[dict allKeys]];
    NSMutableData *dictData = [NSMutableData data];
    __block CFErrorRef error = NULL;
    __block SecTransformRef hashFunction = NULL;
    
    void(^cleanup)(void) = ^(void) {
        if (error != NULL) {
            CFShow(error);
            CFRelease(error);
            error = NULL;
        }
        if (hashFunction != NULL) {
            CFRelease(hashFunction);
            hashFunction = NULL;
        }
    };
    
    // Remove the signature element
    [keyArray removeObject:@"Signature"];
    
    // Sort the keys so we always have a uniform order
    [keyArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
    
    NSUInteger keyIndex = 0, keyCount = [keyArray count];
    for (keyIndex = 0; keyIndex < keyCount; keyIndex++) {
        id curValue = [dict objectForKey:[keyArray objectAtIndex:keyIndex]];
        char *desc = (char *)[[curValue description] UTF8String];
        // We use strlen instead of [string length] so we can get all the bytes of accented characters
        [dictData appendBytes:desc length:strlen(desc)];
    }
    
    // Hash the data
    hashFunction = SecDigestTransformCreate(kSecDigestSHA1, 0, &error);
    if (error != NULL) {
        cleanup();
        return nil;
    }
    
    SecTransformSetAttribute(hashFunction,
                             kSecTransformInputAttributeName,
                             (__bridge CFDataRef)dictData,
                             &error);
    CFDataRef cfHash = SecTransformExecute(hashFunction, &error);
    if (error != NULL) {
        cleanup();
        if (cfHash) {
            CFRelease(cfHash);
        }
        return nil;
    }
    
    NSData *hash = (__bridge_transfer NSData*)cfHash;
    
    cleanup();
    
    return hash;
}

- (NSData*)licenseDataForDictionary:(NSDictionary*)dict {
    __block CFErrorRef error = NULL;
    __block SecTransformRef signFunction = NULL;
    
    void(^cleanup)(void) = ^(void) {
        if (error != NULL) {
            CFShow(error);
            CFRelease(error);
            error = NULL;
        }
        if (signFunction != NULL) {
            CFRelease(signFunction);
            signFunction = NULL;
        }
    };

    // Make sure we have a good key
    if (!self.publicKeyRef || !self.privateKeyRef) {
        [self setAqError:@"RSA key is invalid"];
        return nil;
    }
    
    NSData *hashData = [self computedHashForDictionary:dict];
    
    // Prepare a signing transform, setting the input type as raw data and the input
    // as the hash of the dictionary
    signFunction = SecSignTransformCreate(self.privateKeyRef, &error);
    if (error) {
        cleanup();
        return nil;
    }
    
    SecTransformSetAttribute(signFunction,
                             kSecTransformInputAttributeName,
                             (__bridge CFDataRef)hashData,
                             &error);
    if (error) {
        cleanup();
        return nil;
    }
    
    SecTransformSetAttribute(signFunction,
                             kSecInputIsAttributeName,
                             kSecInputIsRaw,
                             &error);
    if (error) {
        cleanup();
        return nil;
    }
    
    CFDataRef cfSignature = SecTransformExecute(signFunction, &error);
    if (error) {
        cleanup();
        [self setAqError:@"Signature is NULL!"];
        if (cfSignature) {
            CFRelease(cfSignature);
        }
        return nil;
    }

    NSData *signature = (__bridge_transfer NSData*)cfSignature;
    
    // Create the license dictionary
    NSMutableDictionary *licenseDict = [NSMutableDictionary dictionaryWithDictionary:dict];
    [licenseDict setObject:signature forKey:@"Signature"];
    
    // Create the data from the dictionary
    NSError *err = nil;
    NSData *licenseFile = [NSPropertyListSerialization dataWithPropertyList:licenseDict
                                                                     format:kCFPropertyListXMLFormat_v1_0
                                                                    options:0
                                                                      error:&err];
    
    if (licenseFile == NULL) {
        [self setAqError:[err localizedDescription]];
        cleanup();
        return nil;
    }

    cleanup();

    return licenseFile;
}

- (BOOL)writeLicenseFileForDictionary:(NSDictionary*)dict toPath:(NSString *)path {
    NSData *licenseFile = [self licenseDataForDictionary:dict];
    
    if (!licenseFile)
        return NO;
    
    return [licenseFile writeToFile:path atomically:YES];
}

// This method only logs errors on developer problems, so don't expect to grab an error message if it's just an invalid license
- (NSDictionary*)dictionaryForLicenseData:(NSData *)data {
    __block CFErrorRef error = NULL;
    __block SecTransformRef verifyFunction = NULL;
    __block CFBooleanRef valid = NULL;
    
    void(^cleanup)(void) = ^(void) {
        if (error != NULL) {
            CFShow(error);
            CFRelease(error);
            error = NULL;
        }
        if (verifyFunction != NULL) {
            CFRelease(verifyFunction);
            verifyFunction = NULL;
        }
        if (valid != NULL) {
            CFRelease(valid);
            valid = NULL;
        }
    };

    // Make sure public key is set up
    if (!self.publicKeyRef) {
        [self setAqError:@"RSA key is invalid"];
        return nil;
    }
    
    // Create a dictionary from the data
    NSError *err = nil;
    NSMutableDictionary *licenseDict = [NSPropertyListSerialization propertyListWithData:data
                                                                                 options:NSPropertyListMutableContainersAndLeaves
                                                                                  format:NULL
                                                                                   error:&err];
    if (err != nil) {
        cleanup();
        return nil;
    }
    
    NSData *signature = [licenseDict objectForKey:@"Signature"];
    if (signature == nil) {
        cleanup();
        return nil;
    }
    
    NSData *hash = [self computedHashForDictionary:licenseDict];
    NSString *hashCheck = [hash hexDigitRepresentation];
    
    // Store the license hash in case we need it later
    [self setHash:hashCheck];
    
    if (self.blacklist && [self.blacklist containsObject:hashCheck]) {
        cleanup();
        return nil;
    }

    // Verify the signed hash using the public key, passing the raw hash data as the input
    verifyFunction = SecVerifyTransformCreate(self.publicKeyRef, (__bridge CFDataRef)signature, &error);
    if (error) {
        cleanup();
        return nil;
    }
    
    SecTransformSetAttribute(verifyFunction,
                             kSecTransformInputAttributeName,
                             (__bridge CFDataRef)hash,
                             &error);
    if (error) {
        cleanup();
        return nil;
    }

    SecTransformSetAttribute(verifyFunction,
                             kSecInputIsAttributeName,
                             kSecInputIsRaw,
                             &error);
    if (error) {
        cleanup();
        return nil;
    }
    
    valid = SecTransformExecute(verifyFunction, &error);
    if (error) {
        cleanup();
        return nil;
    }
    
    if (valid != kCFBooleanTrue) {
        cleanup();
        return nil;
    }
    
    cleanup();
    
    return [NSDictionary dictionaryWithDictionary:licenseDict];
}

- (NSDictionary*)dictionaryForLicenseFile:(NSString *)path {
    NSData *licenseFile = [NSData dataWithContentsOfFile:path];
    
    if (!licenseFile)
        return nil;
    
    return [self dictionaryForLicenseData:licenseFile];
}

- (BOOL)verifyLicenseData:(NSData *)data {
    if ([self dictionaryForLicenseData:data]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)verifyLicenseFile:(NSString *)path {
    NSData *data = [NSData dataWithContentsOfFile:path];
    return [self verifyLicenseData:data];
}

#pragma mark Error Handling

- (void)setAqError:(NSString *)aqError {
    _aqError = aqError;
#ifndef NDEBUG
    NSLog(@"AquaticPrime error: %@", _aqError);
#endif
}

- (NSString*)getLastError {
    return _aqError;
}

@end
