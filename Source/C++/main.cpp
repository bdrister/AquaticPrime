#include <CoreFoundation/CoreFoundation.h>
#include <getopt.h>

#include "AquaticPrime.h"

int
main(int argc, const char * argv[])
{
	char *key = NULL;
	char *filename = NULL;

	opterr = 0;

	int c;
	while(-1 != (c = getopt (argc, (char * const *)argv, "k:f:"))) {
		switch(c) {
			case 'k':
				key = optarg;
				break;
			case 'f':
				filename = optarg;
				break;
		}
	}

	if(!key || !filename) {
		printf("Usage: %s -k KEY -f FILE\n", argv[0]);
		return EXIT_FAILURE;
	}

	// Set up the parameters
	CFStringRef keyString = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
	CFURLRef fileURL = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (const UInt8 *)filename, strlen(filename), false);

	// Validate the file
	AquaticPrime validator(keyString);
	
	// You can just get back a boolean whether the license data is valid or not:
	CFDictionaryRef licenseDictionary = validator.CreateDictionaryForLicenseFile(fileURL);

	if(licenseDictionary) {
		puts("License verified:");
		CFShow(licenseDictionary);
		CFRelease(licenseDictionary);
	}
	else
		puts("License verification failed!");

	if(keyString)
		CFRelease(keyString);
	if(fileURL)
		CFRelease(fileURL);

    return EXIT_SUCCESS;
}
