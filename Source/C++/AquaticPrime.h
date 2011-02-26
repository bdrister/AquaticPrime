/*
 *  Copyright (C) 2011 Stephen F. Booth <me@sbooth.org>
 *  All Rights Reserved
 */

#pragma once

#include <CoreFoundation/CoreFoundation.h>

#include <openssl/rsa.h>
#include <openssl/sha.h>

class AquaticPrime
{
public:
	AquaticPrime(CFStringRef key);
	~AquaticPrime();

	CFDictionaryRef CreateDictionaryForLicenseFile(CFURLRef path);
	CFDictionaryRef CreateDictionaryForLicenseData(CFDataRef data);

private:
	RSA		*mRSAKey;
};
