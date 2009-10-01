//
// AquaticPrime.m
// AquaticPrime Framework
//
// Copyright (c) 2005, Lucas Newman
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//	¥Redistributions of source code must retain the above copyright notice,
//	 this list of conditions and the following disclaimer.
//	¥Redistributions in binary form must reproduce the above copyright notice,
//	 this list of conditions and the following disclaimer in the documentation and/or
//	 other materials provided with the distribution.
//	¥Neither the name of Aquatic nor the names of its contributors may be used to 
//	 endorse or promote products derived from this software without specific prior written permission.
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

@implementation AquaticPrime

- (id)init
{
	return [self initWithKey:nil privateKey:nil];
}

- (id)initWithKey:(NSString *)key
{	
	return [self initWithKey:key privateKey:nil];
}

- (id)initWithKey:(NSString *)key privateKey:(NSString *)privateKey
{
	ERR_load_crypto_strings();
	
	if (![super init])
		return nil;
	
	aqError = [[NSString alloc] init];
	blacklist = [[NSArray alloc] init];
	hash = [[NSString alloc] init];
    rsaKey = nil;
	
	[self setKey:key privateKey:privateKey];
	
	return self;
}

- (void)dealloc
{	
	ERR_free_strings();
	
	if (rsaKey)
		RSA_free(rsaKey);

	[blacklist release];
	[aqError release];
	[hash release];
	
	[super dealloc];
}

+ (id)aquaticPrimeWithKey:(NSString *)key privateKey:(NSString *)privateKey
{
	return [[[AquaticPrime alloc] initWithKey:key privateKey:privateKey] autorelease];
}

+ (id)aquaticPrimeWithKey:(NSString *)key
{
	return [[[AquaticPrime alloc] initWithKey:key privateKey:nil] autorelease];
}

- (BOOL)setKey:(NSString *)key 
{
	return [self setKey:key privateKey:nil];
}

- (BOOL)setKey:(NSString *)key privateKey:(NSString *)privateKey
{
	// Must have public modulus, private key is optional
	if (!key || [key isEqualToString:@""]) {
		[self _setError:@"Empty public key parameter"];
		return NO;
	}
	
	if (rsaKey)
		RSA_free(rsaKey);
		
	rsaKey = RSA_new();
	
	// We are using the constant public exponent e = 3
	BN_dec2bn(&rsaKey->e, "3");
	
	// Determine if we have hex or decimal values
	int result;
	if ([[key lowercaseString] hasPrefix:@"0x"])
		result = BN_hex2bn(&rsaKey->n, (const char *)[[key substringFromIndex:2] UTF8String]);
	else
		result = BN_dec2bn(&rsaKey->n, (const char *)[key UTF8String]);
		
	if (!result) {
		[self _setError:[NSString stringWithUTF8String:(char*)ERR_error_string(ERR_get_error(), NULL)]];
		return NO;
	}
	
	// Do the private portion if it exists
	if (privateKey && ![privateKey isEqualToString:@""]) {
		if ([[privateKey lowercaseString] hasPrefix:@"0x"])
			result = BN_hex2bn(&rsaKey->d, (const char *)[[privateKey substringFromIndex:2] UTF8String]);
		else
			result = BN_dec2bn(&rsaKey->d, (const char *)[privateKey UTF8String]);
			
		if (!result) {
			[self _setError:[NSString stringWithUTF8String:(char*)ERR_error_string(ERR_get_error(), NULL)]];
			return NO;
		}
	}
	
	return YES;
}

- (NSString *)key
{
	if (!rsaKey || !rsaKey->n)
		return nil;
	
	char *cString = BN_bn2hex(rsaKey->n);
	
	NSString *nString = [[NSString alloc] initWithUTF8String:cString];
	OPENSSL_free(cString);
	
	return nString;
}

- (NSString *)privateKey
{	
	if (!rsaKey || !rsaKey->d)
		return nil;
	
	char *cString = BN_bn2hex(rsaKey->d);
	
	NSString *dString = [[NSString alloc] initWithUTF8String:cString];
	OPENSSL_free(cString);
	
	return dString;
}

- (void)setHash:(NSString *)newHash
{
	[hash release];
	hash = [newHash retain];
}

- (NSString *)hash
{
	return hash;
}

#pragma mark Blacklisting

// This array should contain a list of NSStrings representing hexadecimal hashcodes for blacklisted licenses
- (void)setBlacklist:(NSArray*)hashArray
{
	[blacklist release];
	blacklist = [hashArray retain];
}

#pragma mark Signing

- (NSData*)licenseDataForDictionary:(NSDictionary*)dict
{	
	// Make sure we have a good key
	if (!rsaKey || !rsaKey->n || !rsaKey->d) {
		[self _setError:@"RSA key is invalid"];
		return nil;
	}
	
	// Grab all values from the dictionary
	NSMutableArray *keyArray = [NSMutableArray arrayWithArray:[dict allKeys]];
	NSMutableData *dictData = [NSMutableData data];
	
	// Sort the keys so we always have a uniform order
	[keyArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
	
	int i;
	for (i = 0; i < [keyArray count]; i++)
	{
		id curValue = [dict objectForKey:[keyArray objectAtIndex:i]];
		char *desc = (char *)[[curValue description] UTF8String];
		// We use strlen instead of [string length] so we can get all the bytes of accented characters
		[dictData appendBytes:desc length:strlen(desc)];
	}
	
	// Hash the data
	unsigned char digest[20];
	SHA1([dictData bytes], [dictData length], digest);
	
	// Create the signature from 20 byte hash
	int rsaLength = RSA_size(rsaKey);
	unsigned char *signature = (unsigned char*)malloc(rsaLength);
	int bytes = RSA_private_encrypt(20, digest, signature, rsaKey, RSA_PKCS1_PADDING);
	
	if (bytes == -1) {
		[self _setError:[NSString stringWithUTF8String:(char*)ERR_error_string(ERR_get_error(), NULL)]];
		return nil;
	}
	
	// Create the license dictionary
	NSMutableDictionary *licenseDict = [NSMutableDictionary dictionaryWithDictionary:dict];
	[licenseDict setObject:[NSData dataWithBytes:signature length:bytes]  forKey:@"Signature"];
	
	// Create the data from the dictionary
	NSString *error;
	NSData *licenseFile = [[NSPropertyListSerialization dataFromPropertyList:licenseDict 
														format:kCFPropertyListXMLFormat_v1_0 
														errorDescription:&error] retain];
	
	if (!licenseFile) {
		[self _setError:error];
		return nil;
	}
	
	return licenseFile;
}

- (BOOL)writeLicenseFileForDictionary:(NSDictionary*)dict toPath:(NSString *)path
{
	NSData *licenseFile = [self licenseDataForDictionary:dict];
	
	if (!licenseFile)
		return NO;
	
	return [licenseFile writeToFile:path atomically:YES];
}

// This method only logs errors on developer problems, so don't expect to grab an error message if it's just an invalid license
- (NSDictionary*)dictionaryForLicenseData:(NSData *)data
{	
	// Make sure public key is set up
	if (!rsaKey || !rsaKey->n) {
		[self _setError:@"RSA key is invalid"];
		return nil;
	}

	// Create a dictionary from the data
	NSPropertyListFormat format;
	NSString *error;
	NSMutableDictionary *licenseDict = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListMutableContainersAndLeaves format:&format errorDescription:&error];
	if (![licenseDict isKindOfClass:[NSMutableDictionary class]] || error)
		return nil;
		
	NSData *signature = [licenseDict objectForKey:@"Signature"];
	if (!signature)
		return nil;
	
	// Decrypt the signature - should get 20 bytes back
	unsigned char checkDigest[20];
	if (RSA_public_decrypt([signature length], [signature bytes], checkDigest, rsaKey, RSA_PKCS1_PADDING) != 20)
		return nil;
	
	// Make sure the license hash isn't on the blacklist
	NSMutableString *hashCheck = [NSMutableString string];
	int hashIndex;
	for (hashIndex = 0; hashIndex < 20; hashIndex++)
		[hashCheck appendFormat:@"%02x", checkDigest[hashIndex]];
	
	// Store the license hash in case we need it later
	[self setHash:hashCheck];
	
	if (blacklist && [blacklist containsObject:hashCheck])
			return nil;
	
	// Remove the signature element
	[licenseDict removeObjectForKey:@"Signature"];
	
	// Grab all values from the dictionary
	NSMutableArray *keyArray = [NSMutableArray arrayWithArray:[licenseDict allKeys]];
	NSMutableData *dictData = [NSMutableData data];
	
	// Sort the keys so we always have a uniform order
	[keyArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
	
	int objectIndex;
	for (objectIndex = 0; objectIndex < [keyArray count]; objectIndex++)
	{
		id currentValue = [licenseDict objectForKey:[keyArray objectAtIndex:objectIndex]];
		char *description = (char *)[[currentValue description] UTF8String];
		// We use strlen instead of [string length] so we can get all the bytes of accented characters
		[dictData appendBytes:description length:strlen(description)];
	}
	
	// Hash the data
	unsigned char digest[20];
	SHA1([dictData bytes], [dictData length], digest);
	
	// Check if the signature is a match	
	int checkIndex;
	for (checkIndex = 0; checkIndex < 20; checkIndex++) {
		if (checkDigest[checkIndex] ^ digest[checkIndex])
			return nil;
	}
	
	return [NSDictionary dictionaryWithDictionary:licenseDict];
}

- (NSDictionary*)dictionaryForLicenseFile:(NSString *)path
{
	NSData *licenseFile = [NSData dataWithContentsOfFile:path];
	
	if (!licenseFile)
		return nil;
	
	return [self dictionaryForLicenseData:licenseFile];
}

- (BOOL)verifyLicenseData:(NSData *)data
{
	if ([self dictionaryForLicenseData:data])
		return YES;
	else
		return NO;
}

- (BOOL)verifyLicenseFile:(NSString *)path
{
	NSData *data = [NSData dataWithContentsOfFile:path];
	return [self verifyLicenseData:data];
}

#pragma mark Error Handling

- (NSString*)getLastError
{
	return aqError;
}

@end

@implementation AquaticPrime (Private)

- (void)_setError:(NSString *)err
{
	[aqError release];
	aqError = [err retain];
}

@end