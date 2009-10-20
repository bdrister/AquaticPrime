//
// InfoController.m
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

#import "InfoController.h"
#import "KeyController.h"
#import "AquaticPrime.h"

@implementation InfoController

- (id)init
{
	self = [super initWithWindowNibName:@"LicenseInfo"];
	return self;
}

- (void)awakeFromNib
{
	keyInfoArray = [[NSMutableArray alloc] init];
	valueInfoArray = [[NSMutableArray alloc] init];
	
	[[self window] registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
}

- (IBAction)closeLicenseInfoWindow:(id)sender
{
	[[self window] orderOut:self];
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender
{
}

- (void)draggingEntered:(id <NSDraggingInfo>)sender
{
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return YES;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSArray *filenames = [[sender draggingPasteboard] propertyListForType:NSFilenamesPboardType];
	
	if ([filenames count] != 1)
		return NO;
	
	NSString *licensePath = [filenames objectAtIndex:0];
	if (![self readLicenseAtPath:licensePath])
		return NO;
	
	[licenseWindow setTitle:[licensePath lastPathComponent]];
	NSString *valid = isLicenseValid ? [NSString stringWithFormat:@"This license is valid for %@", licenseValidForProduct] 
									 : @"This license is invalid";
	[licenseValidField setStringValue:valid];
	[hashField setStringValue:[NSString stringWithFormat:@"License Hash: %@", hash]]; 
	[[self window] setContentView:licenseInfoView];
	
	return YES;
}

- (BOOL)readLicenseAtPath:(NSString*)licensePath
{	
	NSDictionary *licenseDictionary;
	
	// If it doesn't have a signature, don't accept the drop
	if (![[NSDictionary dictionaryWithContentsOfFile:licensePath] objectForKey:@"Signature"])
		return NO;
	
	// Grab all the product keys that we have
	NSDictionary *productKeyDictionary = [[KeyController sharedInstance] allPublicKeys];
	NSArray *productArray = [productKeyDictionary allKeys];
	
	// Determine if the license is valid for any of the products
	int productIndex;
	for (productIndex = 0; productIndex < [productArray count]; productIndex++)
	{
		NSString *currentProduct = [productArray objectAtIndex:productIndex];
		NSData *publicKey = [productKeyDictionary objectForKey:currentProduct];
		NSMutableString *publicKeyString = [NSMutableString stringWithString:[publicKey description]];
		[publicKeyString replaceOccurrencesOfString:@" " withString:@"" options:nil range:NSMakeRange(0, [publicKeyString length])];
		[publicKeyString replaceOccurrencesOfString:@"<" withString:@"" options:nil range:NSMakeRange(0, [publicKeyString length])];
		[publicKeyString replaceOccurrencesOfString:@">" withString:@"" options:nil range:NSMakeRange(0, [publicKeyString length])];
		
		AquaticPrime *licenseChecker = [AquaticPrime aquaticPrimeWithKey:[NSString stringWithFormat:@"0x%@", publicKeyString]];
		licenseDictionary = [licenseChecker dictionaryForLicenseFile:licensePath];
		
		if (licenseDictionary) {
			keyInfoArray = [[licenseDictionary allKeys] retain];
			valueInfoArray = [[licenseDictionary allValues] retain];
			hash = (NSString *)[licenseChecker hash];
			isLicenseValid = YES;
			licenseValidForProduct = [currentProduct retain];
			return YES;
		}
	}
	
	// At this point, the license is invalid, but we show the key-value pairs anyway
	NSMutableDictionary *badLicenseDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:licensePath];
	[badLicenseDictionary removeObjectForKey:@"Signature"];
	keyInfoArray = [[NSMutableArray arrayWithArray:[badLicenseDictionary allKeys]] retain];
	valueInfoArray = [[NSMutableArray arrayWithArray:[badLicenseDictionary allValues]] retain];
	
	return YES;
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [keyInfoArray count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if ([[tableColumn identifier] isEqualToString:@"keyInfoColumn"])
		return [keyInfoArray objectAtIndex:row];
	else
		return [valueInfoArray objectAtIndex:row];
}

@end