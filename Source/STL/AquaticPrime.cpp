//
// AquaticPrime.cpp
// AquaticPrime STL Implementation
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

#include "AquaticPrime.h"
#include "tinyxml.h"
#include <stdarg.h>
#include <b64/b64.h>

static RSA *rsaKey;
static std::string hash;
static std::list<std::string> blacklist;

// utilities
inline char ToLower(char in)
{
	return (char)tolower((int)in);
}

const char* CreateCString(std::string output, ...)
{
	static char text[256];
	va_list	ap;

	va_start(ap, output);								// Parses The String For Variables
		vsprintf(text, output.c_str(), ap);				// And Converts Symbols To Actual Numbers
	va_end(ap);					

	return (const char*)text;
}

bool APSetKey(std::string key)
{
	hash = std::string("");
	
	// Create a new key
    rsaKey = RSA_new();
    
    // Public exponent is always 3
	BN_hex2bn(&rsaKey->e, "3");
	
	std::string mutableKey = key;
    
    // Determine if we have a hex or decimal key
	std::transform(mutableKey.begin(), mutableKey.end(), mutableKey.begin(), ToLower); // make mutableKey lowercase
	if(std::string(mutableKey, 0, 2) == "0x")
	{
		mutableKey = std::string(mutableKey, 2, mutableKey.length());
		BN_hex2bn(&rsaKey->n, mutableKey.c_str());
	}
	else 
	{
		BN_dec2bn(&rsaKey->n, mutableKey.c_str());
	}
	
	return true;
}

std::string APHash(void)
{
	return hash;
}

void APSetHash(std::string newHash)
{
	hash = newHash;
}

// Set the entire blacklist array, removing any existing entries
void APSetBlacklist(std::list<std::string> hashArray)
{
	blacklist = hashArray;
}

void APBlacklistAdd(std::string blacklistEntry)
{
	blacklist.push_back(blacklistEntry);
}

std::map<std::string, std::string> APCreateDictionaryForLicenseData(std::map<std::string, std::string> data)
{
	if (!rsaKey->n || !rsaKey->e)
	{
		std::map<std::string, std::string> empty;
		printf("0\n");
		return empty;
	}
	
	// Load the signature
	unsigned char sigBytes[128];
	std::map<std::string, std::string>::iterator signature = data.find("Signature");

    if(signature == data.end())
	{
		std::map<std::string, std::string> empty;
//		printf("1\n");
		return empty;
	}
	else 
	{
		int returnVal = b64::b64_decode(data["Signature"].c_str(), data["Signature"].length(), sigBytes, 129);	
		
		if(returnVal == 0)
		{
			std::map<std::string, std::string> empty;
	//		printf("1.5\n");
			return empty;
		}
		
		data.erase(signature);
	}
	
	// Decrypt the signature
	unsigned char checkDigest[128] = {0};
	if (RSA_public_decrypt(128, sigBytes, checkDigest, rsaKey, RSA_PKCS1_PADDING) != SHA_DIGEST_LENGTH)
    {
		std::map<std::string, std::string> empty;
//		printf("2\n");
		return empty;
	}

	// Get the license hash
	std::string hashCheck;
	int hashIndex;
	for (hashIndex = 0; hashIndex < SHA_DIGEST_LENGTH; hashIndex++)
		hashCheck += CreateCString("%02x", checkDigest[hashIndex]);
	APSetHash(hashCheck);
	
	if (blacklist.size() > 0)
	{
		// $$ is this right?
		for(std::list<std::string>::iterator b = blacklist.begin(); b != blacklist.end(); ++b)
		{
			if(data.find((*b)) != data.end())
			{
				std::map<std::string, std::string> empty;
//				printf("3\n");
				return empty;
			}
		}
	}
	
	// Get the number of elements
	int count = data.size();
	// Load the keys and build up the key array
//	std::list<std::string> keyArray;
	std::string keys[count];
	
	int counter = 0;
	for(std::map<std::string, std::string>::iterator d = data.begin(); d != data.end(); ++d)
	{
		keys[counter] = (*d).first;
		++counter;
	}
	
	// Sort the array ( $$ why?  for cleanliness reasons? )
//	int context = kCFCompareCaseInsensitive;
//	CFArraySortValues(keyArray, CFRangeMake(0, count), (CFComparatorFunction)CFStringCompare, &context);
	
	// Setup up the hash context
	SHA_CTX ctx;
	SHA1_Init(&ctx);
	// Convert into UTF8 strings
	for(int i = 0; i < count; i++)
	{
		std::string key = keys[i]; // $$ convert this to keyArray later
		std::string value = data[key];

		// Account for the null terminator
		SHA1_Update(&ctx, value.c_str(), strlen(value.c_str()));
	}
	unsigned char digest[SHA_DIGEST_LENGTH];
	SHA1_Final(digest, &ctx);
	
	// Check if the signature is a match	
	for (int i = 0; i < SHA_DIGEST_LENGTH; i++) 
	{
		if (checkDigest[i] ^ digest[i]) 
		{
			std::map<std::string, std::string> empty;
//			printf("4\n");
			return empty;
        }
	}

	// If it's a match, we return the dictionary; otherwise, we never reach this
	return data;
}

std::map<std::string, std::string> APCreateDictionaryForLicenseFile(std::string path)
{
	std::map<std::string, std::string> xmlData;
	
	TiXmlNode *node = 0;
	TiXmlDocument licenseFile(path.c_str());
	licenseFile.LoadFile();
	
	node = licenseFile.FirstChild("plist");
	if(node == NULL) return xmlData;
	node = node->FirstChild("dict");
	if(node == NULL) return xmlData;
	
	do
	{
		// <dict>
		if(std::string(node->ToElement()->Value()) == std::string("dict"))
		{
			std::string key, data;
			TiXmlNode *innerNode = node->FirstChild();
			while(innerNode != NULL)
			{				
				// <key>
				if(std::string(innerNode->ToElement()->Value()) == std::string("key"))
				{
					key = innerNode->ToElement()->FirstChild()->Value();
//					printf("key %s\n", key.c_str());
				}
				// <string>
				else if(std::string(innerNode->ToElement()->Value()) == std::string("string"))
				{
					data = innerNode->ToElement()->FirstChild()->Value();
					xmlData[key] = data;
//					printf("string %s %s\n", key.c_str(), data.c_str());
				}
				// <data>
				else if(std::string(innerNode->ToElement()->Value()) == std::string("data"))
				{
					data = innerNode->ToElement()->FirstChild()->Value();
					
					if(key == "Signature") // get rid of any spaces
					{
						std::vector<std::string::iterator> spaces;
						for(std::string::iterator d = data.begin(); d != data.end(); ++d)
						{
							if((*d) == ' ')
								spaces.push_back(d);
						}

						for(uint s=0; s < spaces.size(); ++s)
							data.erase(spaces[s] - (s));
					}
					
					xmlData[key] = data;
//					printf("data %s %s\n", key.c_str(), data.c_str());
				}
				
				innerNode = innerNode->NextSibling();
			}
		}
		
		node = node->NextSibling();
	} while(node != NULL);

	std::map<std::string, std::string> licenseDictionary = APCreateDictionaryForLicenseData(xmlData);

	return licenseDictionary;
}

bool APVerifyLicenseData(std::map<std::string, std::string> data)
{
	std::map<std::string, std::string> licenseDictionary = APCreateDictionaryForLicenseData(data);
	
	if (licenseDictionary.size() > 0)
		return true;
	else
		return false;
}

bool APVerifyLicenseFile(std::string path)
{
	std::map<std::string, std::string> licenseDictionary = APCreateDictionaryForLicenseFile(path);

	if (licenseDictionary.size() > 0)
		return true;
	else
		return false;
}
