/*
 *  Copyright (C) 2011 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#include "AquaticPrime.h"

static int qsort_comparator_func(const void *a, const void *b)
{
	assert(NULL != a);
	assert(NULL != b);

	CFComparisonResult result = CFStringCompare(*reinterpret_cast<const CFStringRef *>(a), 
												*reinterpret_cast<const CFStringRef *>(b), 
												kCFCompareCaseInsensitive);

	return static_cast<int>(result);
}

AquaticPrime::AquaticPrime(CFStringRef key)
	: mRSAKey(NULL)
{
	assert(NULL != key);

	mRSAKey = RSA_new();

	// Public exponent is always 3
	BN_hex2bn(&mRSAKey->e, "3");

	CFRange range = CFRangeMake(CFStringHasPrefix(key, CFSTR("0x")) ? 2 : 0, CFStringGetLength(key));
	CFIndex count;

	// Determine the length of the key in UTF-8
	CFStringGetBytes(key, range, kCFStringEncodingUTF8, 0, false, NULL, 0, &count);
	
	char *buf = new char [count + 1];
	
	// Convert it
	CFIndex used;
	CFStringGetBytes(key, range, kCFStringEncodingUTF8, 0, false, reinterpret_cast<UInt8 *>(buf), count, &used);

	// Add terminator
	buf[used] = '\0';

	BN_hex2bn(&mRSAKey->n, buf);

	delete [] buf;
}

AquaticPrime::~AquaticPrime()
{
	if(mRSAKey)
		RSA_free(mRSAKey), mRSAKey = NULL;
}

CFDictionaryRef AquaticPrime::CreateDictionaryForLicenseFile(CFURLRef path)
{
	assert(NULL != path);

	CFDataRef data;
	SInt32 errorCode;
	Boolean status = CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, path, &data, NULL, NULL, &errorCode);

	if(0 != errorCode || true != status)
		return NULL;

	CFDictionaryRef licenseDictionary = CreateDictionaryForLicenseData(data);

	CFRelease(data), data = NULL;

	return licenseDictionary;
}

CFDictionaryRef AquaticPrime::CreateDictionaryForLicenseData(CFDataRef data)
{
	assert(NULL != data);

	if(!mRSAKey || !mRSAKey->n || !mRSAKey->e)
		return NULL;

	// Make the property list from the data
	CFStringRef errorString = NULL;
	CFPropertyListRef propertyList = CFPropertyListCreateFromXMLData(kCFAllocatorDefault, 
																	 data, 
																	 kCFPropertyListMutableContainers, 
																	 &errorString);

	if(errorString || CFDictionaryGetTypeID() != CFGetTypeID(propertyList) || !CFPropertyListIsValid(propertyList, kCFPropertyListXMLFormat_v1_0)) {
		if(propertyList)
			CFRelease(propertyList), propertyList = NULL;
		return NULL;
	}
    
	// Load the signature
	CFMutableDictionaryRef licenseDictionary = (CFMutableDictionaryRef)propertyList;
	if(!CFDictionaryContainsKey(licenseDictionary, CFSTR("Signature"))) {
		CFRelease(licenseDictionary), licenseDictionary = NULL;
		return NULL;
	}
    
	CFDataRef signatureData = reinterpret_cast<CFDataRef>(CFDictionaryGetValue(licenseDictionary, CFSTR("Signature")));

	// Decrypt the signature
	unsigned char checkDigest [RSA_size(mRSAKey) - 11];

	int checkDigestLength = RSA_public_decrypt(static_cast<int>(CFDataGetLength(signatureData)), 
											   CFDataGetBytePtr(signatureData), 
											   checkDigest, 
											   mRSAKey, 
											   RSA_PKCS1_PADDING);

    if(SHA_DIGEST_LENGTH != checkDigestLength) {
		CFRelease(licenseDictionary), licenseDictionary = NULL;
		return NULL;
	}

	// Get the number of elements
	CFDictionaryRemoveValue(licenseDictionary, CFSTR("Signature"));
	CFIndex dictionaryPairCount = CFDictionaryGetCount(licenseDictionary);

	// Get and sort the keys
	CFStringRef keys [dictionaryPairCount];
	CFDictionaryGetKeysAndValues(licenseDictionary, reinterpret_cast<const void **>(&keys), NULL);

	qsort(keys, dictionaryPairCount, sizeof(CFStringRef), qsort_comparator_func);

	// Setup up the hash context
	SHA_CTX ctx;
	SHA1_Init(&ctx);
	
	// Convert into UTF8 strings
	for(CFIndex i = 0; i < dictionaryPairCount; ++i) {
		CFStringRef value = reinterpret_cast<CFStringRef>(CFDictionaryGetValue(licenseDictionary, keys[i]));

		CFRange range = CFRangeMake(0, CFStringGetLength(value));
		CFIndex count;
		
		// Determine the length of the key in UTF-8
		CFStringGetBytes(value, range, kCFStringEncodingUTF8, 0, false, NULL, 0, &count);
		
		char *buf = new char [count];
		
		// Convert it
		CFIndex used;
		CFStringGetBytes(value, range, kCFStringEncodingUTF8, 0, false, reinterpret_cast<UInt8 *>(buf), count, &used);
		
		SHA1_Update(&ctx, buf, used);

		delete [] buf;
	}

	unsigned char digest[SHA_DIGEST_LENGTH];
	SHA1_Final(digest, &ctx);

	// Check if the signature is a match    
	for(int i = 0; i < SHA_DIGEST_LENGTH; ++i) {
		if(checkDigest[i] ^ digest[i]) {
			CFRelease(licenseDictionary), licenseDictionary = NULL;
			return NULL;
		}
	}

	return licenseDictionary;
}
