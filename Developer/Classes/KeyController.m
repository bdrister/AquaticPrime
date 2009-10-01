//
// KeyController.m
// AquaticPrime Developer
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

#import "KeyController.h"
#import "ProductController.h"
#import "StatusController.h"

@implementation KeyController

#pragma mark Setup

static KeyController *sharedInstance = nil;

- (id)init
{
	if (sharedInstance) {
        [self dealloc];
    } else {
        sharedInstance = [super init];
    }
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewKeysForCurrentProduct) name:@"ProductSelected" object:nil];
	
	return sharedInstance;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem
{
	if ([[aMenuItem title] isEqualToString:@"Export Keys..."]) {
		if (![productController currentProduct])
			return NO;
	}
	
	return YES;
}

+ (KeyController *)sharedInstance
{
    return sharedInstance ? sharedInstance : [[self alloc] init];
}

#pragma mark Getting Keys

- (NSString *)publicKey
{
	NSString *nString;
	char *cString;
	
	if (!rsaKey->n)
		return nil;
	
	cString = BN_bn2hex(rsaKey->n);
	
	nString = [[[NSString stringWithFormat:@"0x%s", cString] retain] autorelease];
	OPENSSL_free(cString);
	
	return nString;
}

- (NSString *)privateKey
{
	NSString *nString;
	char *cString;
	
	if (!rsaKey->d)
		return nil;
	
	cString = BN_bn2hex(rsaKey->d);
	
	nString = [[[NSString stringWithFormat:@"0x%s", cString] retain] autorelease];
	OPENSSL_free(cString);
	
	return nString;
}

- (NSDictionary*)allPublicKeys
{
	NSArray *products = [productController allProducts];
	NSMutableDictionary *productKeyDictionary = [NSMutableDictionary dictionary];
	
	int productIndex;
	for (productIndex = 0; productIndex < [products count]; productIndex++)
	{
		NSString *productPath = [[@"~/Library/Application Support/Aquatic/Product Keys" stringByExpandingTildeInPath] 
								stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", [products objectAtIndex:productIndex]]];
	
		// Load the public key
		NSData *pubData = [[NSDictionary dictionaryWithContentsOfFile:productPath] objectForKey:@"Public Key"];
		
		[productKeyDictionary setObject:pubData forKey:[products objectAtIndex:productIndex]];
	}
	
	return productKeyDictionary;
}

#pragma mark Viewing Keys

- (void)viewKeysForCurrentProduct
{
	if ([productController currentProduct]) {
		[generateButton setEnabled:YES];
		[self loadKeysForProduct:[productController currentProduct]];
	}
	else {
		[generateButton setEnabled:NO];
		[rsaKeyView setString:@""];
		[publicKeyView setString:@""];
		[privateKeyView setString:@""];
	}
}

#define WINDOW_THRESH 30

- (void)populateKeyView
{
	// The public key
	NSString *pubKey = [NSString stringWithFormat:@"0x%s", BN_bn2hex(rsaKey->n)];
	// How many characters we have left
	int lengthLeft = [pubKey length];
	// Where we are now
	int curPos = 0;
	
	NSMutableString *pubConstruct = [NSMutableString stringWithString:@"\n\t// This string is specially constructed to prevent key replacement \
	// *** Begin Public Key ***\n\tNSMutableString *key = [NSMutableString string];\n"];
	
	while ((lengthLeft - WINDOW_THRESH) > 0) {
		// Logic to check for repeats
		int repeated = 0;
		char charBuf = 0;
		int i;
		for (i = curPos; i < WINDOW_THRESH + curPos; i++) {
			// We have a repeat!
			if (charBuf == [pubKey characterAtIndex:i]) {
				// Print up to repeat
				[pubConstruct appendString:[NSString stringWithFormat:@"\t[key appendString:@\"%@\"];\n", [pubKey substringWithRange:NSMakeRange(curPos, (i-1) - curPos)]]];
				//Do the repeat
				[pubConstruct appendString:[NSString stringWithFormat:@"\t[key appendString:@\"%@\"];\n", [pubKey substringWithRange:NSMakeRange(i-1, 1)]]];
				[pubConstruct appendString:[NSString stringWithFormat:@"\t[key appendString:@\"%@\"];\n", [pubKey substringWithRange:NSMakeRange(i, 1)]]];
				// Finish the line
				[pubConstruct appendString:[NSString stringWithFormat:@"\t[key appendString:@\"%@\"];\n", [pubKey substringWithRange:NSMakeRange(i+1, (WINDOW_THRESH + curPos) - (i+1))]]];
				repeated = 1;
				break;
			}
			charBuf = [pubKey characterAtIndex:i];
		}
		// No repeats
		if (!repeated)
			[pubConstruct appendString:[NSString stringWithFormat:@"\t[key appendString:@\"%@\"];\n", [pubKey substringWithRange:NSMakeRange(curPos, WINDOW_THRESH)]]];
		
		lengthLeft -= WINDOW_THRESH;
		curPos += WINDOW_THRESH;
	}
	[pubConstruct appendString:[NSString stringWithFormat:@"\t[key appendString:@\"%@\"];\n\t// *** End Public Key *** \n", [pubKey substringWithRange:NSMakeRange(curPos, lengthLeft)]]];
	
	// Populate key view
	[rsaKeyView setString:pubConstruct];
	[publicKeyView setString:[self publicKey]];
	[privateKeyView setString:[self privateKey]];
}

#pragma mark Key Generation

- (IBAction)generateKey:(id)sender
{
	if ([productController currentProduct])
		[self generateKeyForProduct:[productController currentProduct]];
}

- (void)generateKeyForProduct:(NSString *)productName
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = [@"~/Library/Application Support/Aquatic" stringByExpandingTildeInPath];
	NSString *keyDir = [supportDir stringByAppendingString:@"/Product Keys"];
	NSString *productPath = [keyDir stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", productName]];
	NSString *warningString = [NSString stringWithFormat:
								@"Are you sure you want to generate a new key for %@?", productName];
	
	[tabView selectLastTabViewItem:self];
	
	if ([fm fileExistsAtPath:productPath]) {
		if (NSRunInformationalAlertPanel(warningString, @"The old product key will be erased.", @"OK", @"Cancel", nil) == NSAlertAlternateReturn)
			return;
		else
			[fm movePath:productPath toPath:[productPath stringByAppendingString:@".old"] handler:nil];
	}
	
	if (rsaKey)
		RSA_free(rsaKey);
	
	rsaKey = RSA_generate_key(1024, 3, NULL, NULL);
	
	[self populateKeyView];
	[statusController setStatus:@"Generated 1024-bit key" duration:2.5];
	[self saveKeysForProduct:productName];
	
	// Notify about the new key
	[[NSNotificationCenter defaultCenter] postNotificationName:@"NewKeyGenerated" object:nil];
}

#pragma mark Loading and Saving

// loadKeysForProduct: returns YES if the pair already exists, otherwise generates a new key and returns NO
- (BOOL)loadKeysForProduct:(NSString *)productName
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *productPath = [[@"~/Library/Application Support/Aquatic/Product Keys" stringByExpandingTildeInPath] 
								stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", productName]];

	// Generate a key if it doesn't exist
	if (![fm fileExistsAtPath:productPath]) {
		[self generateKey:self];
		return NO;
	}
	
	// Load the dict
	NSDictionary *keyDict = [NSDictionary dictionaryWithContentsOfFile:productPath];
	NSData *pubData = [keyDict objectForKey:@"Public Key"];
	NSData *privData = [keyDict objectForKey:@"Private Key"];
	
	if (rsaKey)
		RSA_free(rsaKey);
	
	rsaKey = RSA_new();
	rsaKey->n = BN_bin2bn([pubData bytes], [pubData length], NULL);
	rsaKey->d = BN_bin2bn([privData bytes], [privData length], NULL);
	
	[self populateKeyView];
	//[statusController setStatus:[NSString stringWithFormat:@"Loaded key for %@", productName] duration:2.5];
	
	return YES;
}

- (BOOL)saveKeysForProduct:(NSString *)productName
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = [@"~/Library/Application Support/Aquatic" stringByExpandingTildeInPath];
	NSString *keyDir = [supportDir stringByAppendingString:@"/Product Keys"];
	NSString *productPath = [keyDir stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", productName]];
	BOOL isDir;
	NSData *pubData;
	NSData *privData;
	unsigned char *pubBytes;
	unsigned char *privBytes;
	int pubLength = BN_num_bytes(rsaKey->n);
	int privLength = BN_num_bytes(rsaKey->d);
	
	// Get the bytes for each key and copy the bytes
	pubBytes = (unsigned char*)malloc(pubLength);
	BN_bn2bin(rsaKey->n, pubBytes);
	privBytes = (unsigned char*)malloc(privLength);
	BN_bn2bin(rsaKey->d, privBytes);
	
	// Create the NSData objects
	pubData =  [NSData dataWithBytesNoCopy:pubBytes length:pubLength freeWhenDone:YES];
	privData =  [NSData dataWithBytesNoCopy:privBytes length:privLength freeWhenDone:YES];
	
	// Create the dictionary
	NSDictionary *keyDict = [NSDictionary dictionaryWithObjectsAndKeys: pubData, @"Public Key", privData, @"Private Key", nil];
	
	// The ~/Library/Application Support/Aquatic/ folder doesn't exist yet
	if (![fm fileExistsAtPath:supportDir isDirectory:&isDir])
	{
		// Create the ~/Library/Application Support/Aquatic/ directory
		[fm createDirectoryAtPath:supportDir attributes:nil];
	}
	// The support path leads to a file! Bad!
	else if (!isDir)
	{
		NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"%@ already exists as a file.  Can't create support directory.", supportDir], 
						@"OK", nil, nil);
		return NO;
	}
	
	if  (![fm fileExistsAtPath:keyDir isDirectory:&isDir])
	{
		// Create the product key directory
		[fm createDirectoryAtPath:keyDir attributes:nil];
	}
	// The key directory path leads to a file! Bad again!
	else if (!isDir)
	{
		NSRunAlertPanel(@"Error", [NSString stringWithFormat:@"%@ already exists as a file.  Can't create key storage directory.", keyDir], 
						@"OK", nil, nil);
		return NO;
	}
	
	[keyDict writeToFile:productPath atomically:YES];
	return YES;
}

- (IBAction)exportKeys:(id)sender
{
	// Run the selection panel
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setPrompt:@"Export"];
	[savePanel setTitle:@"Export Keys To..."];
	if ([savePanel runModal] == NSFileHandlingPanelCancelButton)
		return;
	
	NSString *exportPath = [savePanel filename];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *productPath = [[NSString stringWithFormat:@"~/Library/Application Support/Aquatic/Product Keys/%@.plist", 
															[productController currentProduct]] stringByExpandingTildeInPath];
																																
	[fm copyPath:productPath toPath:exportPath handler:nil];
}

- (IBAction)importKeys:(id)sender
{
	// Run the selection panel
	NSOpenPanel *selectPanel = [NSOpenPanel openPanel];
	[selectPanel setCanChooseFiles:YES];
	[selectPanel setCanChooseDirectories:NO];
	[selectPanel setAllowsMultipleSelection:NO];
	[selectPanel setPrompt:@"Select"];
	[selectPanel setTitle:@"Select Key File"];
	if ([selectPanel runModal] == NSFileHandlingPanelCancelButton)
		return;
	
	NSString *keyPath = [[selectPanel filenames] objectAtIndex:0];
	
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:keyPath];
	if (![[dict allKeys] containsObject:@"Public Key"] || ![[dict allKeys] containsObject:@"Private Key"]) {
		NSRunAlertPanel(@"Error", @"This file does not contain a proper keypair", @"OK", nil, nil);
		return;
	}
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *productPath = [[NSString stringWithFormat:@"~/Library/Application Support/Aquatic/Product Keys/%@.plist", 
															[keyPath lastPathComponent]] stringByExpandingTildeInPath];
																																
	[fm copyPath:keyPath toPath:productPath handler:nil];
	[productController loadProducts];
}

@end
