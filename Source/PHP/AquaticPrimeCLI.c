//
// AquaticPrimeCLI.m
// AquaticPrime
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
//	¥Neither the name of the Aquatic nor the names of its contributors may be used to 
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

#include <stdio.h>
#include <string.h>
#include <openssl/rsa.h>
#include <openssl/sha.h>

int main(int argc, char *argv[])
{
    RSA* rsaKey;
    unsigned char digest[20], signature[128];
    int i, encryptedLength;

    if (argc != 4)
        return -1;
    
    rsaKey = RSA_new();
    BN_hex2bn(&rsaKey->n, argv[1]);
    BN_hex2bn(&rsaKey->d, argv[2]);
    BN_dec2bn(&rsaKey->e, "3");
	
	if (BN_num_bits(rsaKey->n) != 1024) {
	   RSA_free(rsaKey);
	   return -1;
	}
	
	SHA1((unsigned char*)argv[3], strlen(argv[3]), digest);
	
	encryptedLength = RSA_private_encrypt(20, digest, signature, rsaKey, RSA_PKCS1_PADDING);
	
	for (i = 0; i < encryptedLength; i++)
	   fprintf(stdout, "%c", signature[i]);
	
	return 0;
}
