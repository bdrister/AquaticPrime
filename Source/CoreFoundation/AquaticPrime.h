//
// AquaticPrime.h
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

#include <CoreFoundation/CoreFoundation.h>

CF_EXTERN_C_BEGIN

// Set the key - must be called first
CF_EXPORT Boolean APSetKey(CFStringRef newKey);

// Validating & extracting licenses
CF_EXPORT CFDictionaryRef APCreateDictionaryForLicenseData(CFDataRef data);
CF_EXPORT CFDictionaryRef APCreateDictionaryForLicenseFile(CFURLRef path);
CF_EXPORT Boolean APVerifyLicenseData(CFDataRef data);
CF_EXPORT Boolean APVerifyLicenseFile(CFURLRef path);

CF_EXPORT void APBlacklistAdd(CFStringRef blacklistEntry);
CF_EXPORT void APSetBlacklist(CFArrayRef hashArray);

CF_EXTERN_C_END
