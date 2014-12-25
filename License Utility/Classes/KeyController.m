//
// KeyController.m
// AquaticPrime Developer
//
// Copyright (c) 2005-2011, Lucas Newman and other contributors
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
#import "AquaticPrime.h"
#import "NSData+HexDigits.h"

@implementation KeyController

#pragma mark Setup

static KeyController *sharedInstance = nil;

- (id)init
{
	if (sharedInstance) {
    } else {
        sharedInstance = [super init];
		[[NSNotificationCenter defaultCenter] addObserver:sharedInstance selector:@selector(viewKeysForCurrentProduct) name:@"ProductSelected" object:nil];
    }
	
	return sharedInstance;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem
{
	if (aMenuItem.tag == 105) {
		// "Export Keys..."
		if (![productController currentProduct]) {
			return NO;
		}
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
	NSString *nString = [keyGenerator key];
	
	if (!nString)
		return nil;
	
	return nString;
}

- (NSString *)privateKey
{
	NSString *nString = [keyGenerator privateKey];

	if (!nString)
		return nil;
	
	return nString;
}

- (NSDictionary*)allPublicKeys
{
	NSArray *products = [productController allProducts];
	NSMutableDictionary *productKeyDictionary = [NSMutableDictionary dictionary];
	
	int productIndex;
	for (productIndex = 0; productIndex < [products count]; productIndex++)
	{
		NSString *productPath = [[DATADIR_PATH stringByAppendingPathComponent:@"Product Keys"] 
								stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", [products objectAtIndex:productIndex]]];
	
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
	NSString *pubKey = [self publicKey];
	// How many characters we have left
	int lengthLeft = [pubKey length];
	// Where we are now
	int curPos = 0;
	
	NSMutableString *pubConstruct = [NSMutableString stringWithString:@"\n\t// This string is specially constructed to prevent key replacement \
                                     // *** Begin Public Key ***\n\tCFMutableStringRef key = CFStringCreateMutable(NULL, 0);\n"];
    
    while ((lengthLeft - WINDOW_THRESH) > 0) {
		// Logic to check for repeats
		int repeated = 0;
		char charBuf = 0;
		int i;
		for (i = curPos; i < WINDOW_THRESH + curPos; i++) {
			// We have a repeat!
			if (charBuf == [pubKey characterAtIndex:i]) {
				// Print up to repeat
				[pubConstruct appendString:[NSString stringWithFormat:@"\tCFStringAppend(key, CFSTR(\"%@\"));\n", [pubKey substringWithRange:NSMakeRange(curPos, (i-1) - curPos)]]];
				//Do the repeat
				[pubConstruct appendString:[NSString stringWithFormat:@"\tCFStringAppend(key, CFSTR(\"%@\"));\n", [pubKey substringWithRange:NSMakeRange(i-1, 1)]]];
				[pubConstruct appendString:[NSString stringWithFormat:@"\tCFStringAppend(key, CFSTR(\"%@\"));\n", [pubKey substringWithRange:NSMakeRange(i, 1)]]];
				// Finish the line
				[pubConstruct appendString:[NSString stringWithFormat:@"\tCFStringAppend(key, CFSTR(\"%@\"));\n", [pubKey substringWithRange:NSMakeRange(i+1, (WINDOW_THRESH + curPos) - (i+1))]]];
				repeated = 1;
				break;
			}
			charBuf = [pubKey characterAtIndex:i];
		}
		// No repeats
		if (!repeated)
			[pubConstruct appendString:[NSString stringWithFormat:@"\tCFStringAppend(key, CFSTR(\"%@\"));\n", [pubKey substringWithRange:NSMakeRange(curPos, WINDOW_THRESH)]]];
		
		lengthLeft -= WINDOW_THRESH;
		curPos += WINDOW_THRESH;
	}
	[pubConstruct appendString:[NSString stringWithFormat:@"\tCFStringAppend(key, CFSTR(\"%@\"));\n\t// *** End Public Key *** \n", [pubKey substringWithRange:NSMakeRange(curPos, lengthLeft)]]];
	
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
	NSString *keyDir = [DATADIR_PATH stringByAppendingPathComponent:@"Product Keys"];
	NSString *productPath = [keyDir stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@.plist", productName]];
	NSString *warningString = [NSString stringWithFormat:
								@"Are you sure you want to generate a new key for %@?", productName];
	
	[tabView selectLastTabViewItem:self];
	
	if ([fm fileExistsAtPath:productPath]) {
		if (NSRunInformationalAlertPanel(warningString, @"The old product key will be erased.", @"OK", @"Cancel", nil) == NSAlertAlternateReturn)
			return;
		else
			[fm moveItemAtPath:productPath toPath:[productPath stringByAppendingString:@".old"] error:NULL];
	}
	
	keyGenerator = [[AquaticPrime alloc] init];
    [keyGenerator generateKeys];
	
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
	NSString *productPath = [[DATADIR_PATH stringByAppendingPathComponent:@"Product Keys"] 
								stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", productName]];

	// Generate a key if it doesn't exist
	if (![fm fileExistsAtPath:productPath]) {
		[self generateKey:self];
		return NO;
	}
	
	// Load the dict
	NSDictionary *keyDict = [NSDictionary dictionaryWithContentsOfFile:productPath];
    
    // Old raw format or new PEM encoded format?
    id pubKeyFormatUnknown = [keyDict objectForKey:@"Public Key"];
	id privKeyFormatUnknown = [keyDict objectForKey:@"Private Key"];

    NSString *pubKey = nil, *privKey = nil;
    if ([pubKeyFormatUnknown isKindOfClass:[NSString class]] && [privKeyFormatUnknown isKindOfClass:[NSString class]]) {
        // This is the new PEM encoded type (I'm happy to believe that and skip validation in a developer tool anyway)
        pubKey = pubKeyFormatUnknown;
        privKey = privKeyFormatUnknown;
    }
    else {
        // This is the old format (NSData raw key). If we can convert the private key into a PEM encoded string
        // that will move things along nicely, and we won't need to continue using the raw 1024 bit unencoded keys
        // anymore.
        pubKey = [pubKeyFormatUnknown hexDigitRepresentation];
        privKey = [privKeyFormatUnknown hexDigitRepresentation];
    }
	keyGenerator = [AquaticPrime aquaticPrimeWithKey:pubKey privateKey:privKey];
	
	[self populateKeyView];
	//[statusController setStatus:[NSString stringWithFormat:@"Loaded key for %@", productName] duration:2.5];
	
	return YES;
}

- (BOOL)saveKeysForProduct:(NSString *)productName
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = DATADIR_PATH;
	NSString *keyDir = [supportDir stringByAppendingPathComponent:@"Product Keys"];
	NSString *productPath = [keyDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", productName]];
	BOOL isDir;
	
	// Create the dictionary
	NSDictionary *keyDict = [NSDictionary dictionaryWithObjectsAndKeys:
                             [keyGenerator key], @"Public Key",
                             [keyGenerator privateKey], @"Private Key", nil];
	
	// The data directory doesn't exist yet
	if (![fm fileExistsAtPath:supportDir isDirectory:&isDir])
	{
		// Create the data directory
		[fm createDirectoryAtPath:supportDir withIntermediateDirectories:YES attributes:nil error:NULL];
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
		[fm createDirectoryAtPath:keyDir withIntermediateDirectories:YES attributes:nil error:NULL];
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

	NSString *exportPath = [[savePanel URL] path];
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *productPath = [[DATADIR_PATH stringByAppendingFormat:@"/Product Keys/%@.plist", 
															[productController currentProduct]] stringByExpandingTildeInPath];
																																
	[fm copyItemAtPath:productPath toPath:exportPath error:NULL];
}

- (IBAction)importKeys:(id)sender
{
	// Run the selection panel
	NSOpenPanel *selectPanel = [NSOpenPanel openPanel];
	[selectPanel setCanChooseFiles:YES];
	[selectPanel setCanChooseDirectories:NO];
	[selectPanel setAllowsMultipleSelection:NO];
	[selectPanel setPrompt:@"Choose"];
	[selectPanel setTitle:@"Choose Key File"];
	if ([selectPanel runModal] == NSFileHandlingPanelCancelButton)
		return;
	
	NSString *keyPath = [[selectPanel URL] path];
	
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:keyPath];
	if (![[dict allKeys] containsObject:@"Public Key"] || ![[dict allKeys] containsObject:@"Private Key"]) {
		NSRunAlertPanel(@"Error", @"This file does not contain a proper keypair", @"OK", nil, nil);
		return;
	}
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *productPath = [[DATADIR_PATH stringByAppendingFormat:@"/Product Keys/%@.plist", 
							  [keyPath lastPathComponent]] stringByExpandingTildeInPath];
	
	[fm copyItemAtPath:keyPath toPath:productPath error:NULL];
	[productController loadProducts];
}

- (void)importKeyAsPrivate:(BOOL)asPrivate
{
	// Run the selection panel
	NSOpenPanel *selectPanel = [NSOpenPanel openPanel];
	[selectPanel setCanChooseFiles:YES];
	[selectPanel setCanChooseDirectories:NO];
	[selectPanel setAllowsMultipleSelection:NO];
	[selectPanel setPrompt:@"Choose"];
	[selectPanel setTitle:[NSString stringWithFormat:@"Choose %@ Key File", asPrivate?@"Private":@"Public"]];
	if ([selectPanel runModal] == NSFileHandlingPanelCancelButton)
		return;
	
	// Read the file contents
	NSString *keyPath = [[selectPanel URL] path];
	NSString *fileContent = [NSString stringWithContentsOfFile:keyPath encoding:NSASCIIStringEncoding error:nil];
	
	// The data is expected to be a PEM encoded file
	if (!asPrivate) {
        [keyGenerator setKey:fileContent];
    }
    else {
        [keyGenerator setKey:[keyGenerator key] privateKey:fileContent];
    }
	
	[self saveKeysForProduct:[productController currentProduct]];
	[productController loadProducts];
}

- (IBAction)importPublicKey:(id)sender
{
	[self importKeyAsPrivate:NO];
}

- (IBAction)importPrivateKey:(id)sender
{
	[self importKeyAsPrivate:YES];
}

- (NSMenu *)textView:(NSTextView *)view menu:(NSMenu *)menu forEvent:(NSEvent *)event atIndex:(NSUInteger)charIndex NS_AVAILABLE_MAC(10_5)
{
	if (![productController currentProduct]) {
		// user needs to select a key pair first, then he can replace it this way
	} else {
		NSMenuItem *item = nil;
		if (view == publicKeyView) {
			item = [[NSMenuItem alloc] initWithTitle:@"Import Public Key..." action:@selector(importPublicKey:) keyEquivalent:@""];
		} else if (view == privateKeyView) {
			item = [[NSMenuItem alloc] initWithTitle:@"Import Private Key..." action:@selector(importPrivateKey:) keyEquivalent:@""];
		}
		item.target = self;
		[menu addItem:[NSMenuItem separatorItem]];
		[menu addItem:item];
	}
	return menu;
}

@end
