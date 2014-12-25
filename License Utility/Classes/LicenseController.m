//
// LicenseController.m
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

#import "LicenseController.h"
#import "KeyController.h"
#import "StatusController.h"
#import "ProductController.h"
#import "AquaticPrime.h"
#import "AQTableView.h"

@implementation LicenseController

#pragma mark Init

- (id)init
{
	self = [super init];
	if(self) {
		keyArray = [NSMutableArray array];
		valueArray = [NSMutableArray array];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newProductSelected) name:@"ProductSelected" object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveLicenseTemplate:) name:@"ProductWillBeSelected" object:nil];
	}
	
	return self;
}
 
- (void)dealloc
{
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark License Generation

- (IBAction)generateLicense:(id)sender
{
	NSString *errorString;
	
	if ([keyArray count] == 0) {
		errorString = @"Please assign at least one key-value pair.";
		NSRunAlertPanel(@"Could not create license file", errorString, @"OK", nil, nil);
		return;
	}
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = DATADIR_PATH;
	NSString *licenseDir = [supportDir stringByAppendingPathComponent:@"Generated Licenses"];
	BOOL isDir;
	
	// The data directory doesn't exist yet
	if (![fm fileExistsAtPath:supportDir isDirectory:&isDir])
	{
		// The support path leads to a file! Bad! This shouldn't happen ever!!
		if (!isDir)
			[fm removeItemAtPath:supportDir error:NULL];
		
		// Create the data directory
		[fm createDirectoryAtPath:supportDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}

	// The Generated Licenses folder doesn't exist yet
	if  (![fm fileExistsAtPath:licenseDir isDirectory:&isDir])
	{
		// The licenses path leads to a file! Bad! This shouldn't happen ever!!
		if (!isDir)
			[fm removeItemAtPath:licenseDir error:NULL];
			
		// Create the product key directory
		[fm createDirectoryAtPath:licenseDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	NSMutableDictionary *licenseDict = [NSMutableDictionary dictionaryWithObjects:valueArray forKeys:keyArray];
	
	NSString *publicKey = [keyController publicKey];
	NSString *privateKey = [keyController privateKey];
	
	if (!publicKey || !privateKey)
		return;
	
	licenseMaker = [AquaticPrime aquaticPrimeWithKey:publicKey privateKey:privateKey];
	
	NSString *path = [NSString stringWithFormat:@"%@/%@.%@", [saveDirectoryField stringValue], [valueArray objectAtIndex:0], [licenseExtensionField stringValue]];
	NSString *backupPath = [NSString stringWithFormat:@"%@/%@.%@", licenseDir, [valueArray objectAtIndex:0], [licenseExtensionField stringValue]];
	[licenseMaker writeLicenseFileForDictionary:licenseDict toPath:path];
	[licenseMaker writeLicenseFileForDictionary:licenseDict toPath:backupPath];
	[statusController setStatus:[NSString stringWithFormat:@"Wrote license to %@", path] duration:2.5];
}
 
#pragma mark Saving & Loading License Templates

- (void)saveLicenseTemplate:(id)anObject
{	
	// Make sure the object is a tableView
	int index = -1;
	if ([anObject respondsToSelector:@selector(object)] && [[anObject object] respondsToSelector:@selector(selectedRow)])
		index = [[anObject object] selectedRow];

	if (index < 0)
		return;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = DATADIR_PATH;
	NSString *templateDir = [supportDir stringByAppendingPathComponent:@"License Templates"];
	NSString *productPath = [templateDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", [productController productAtIndex:index]]];
	BOOL isDir;
	
	// Save this way to preserve the order of items
	NSDictionary *templateDict = [NSDictionary dictionaryWithObjectsAndKeys:keyArray, @"Keys", 
																			valueArray, @"Values", 
																			[licenseExtensionField stringValue], @"Extension",
																			[saveDirectoryField stringValue], @"Save Directory", nil];
	
	// The data directory doesn't exist yet
	if (![fm fileExistsAtPath:supportDir isDirectory:&isDir])
	{
		// The support path leads to a file! Bad! This shouldn't happen ever!!
		if (!isDir)
			[fm removeItemAtPath:supportDir error:NULL];
		
		// Create the data directory
		[fm createDirectoryAtPath:supportDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	// The License Templates folder doesn't exist yet
	if  (![fm fileExistsAtPath:templateDir isDirectory:&isDir])
	{
		// The template path leads to a file! Bad! This shouldn't happen ever!!
		if (!isDir)
			[fm removeItemAtPath:templateDir error:NULL];
			
		// Create the product key directory
		[fm createDirectoryAtPath:templateDir withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	[templateDict writeToFile:productPath atomically:YES];

	return;
}
 
- (BOOL)loadLicenseTemplate
{
	if (![productController currentProduct])
		return NO;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = DATADIR_PATH;
	NSString *templateDir = [supportDir stringByAppendingPathComponent:@"License Templates"];
	NSString *productPath = [[templateDir stringByAppendingPathComponent:[productController currentProduct]] stringByAppendingPathExtension:@"plist"];

	if (![fm fileExistsAtPath:productPath])
	{
		[licenseExtensionField setStringValue:@"plist"];
		[licenseExtensionEditField setStringValue:@"plist"];
		[saveDirectoryField setStringValue:[@"~/Documents" stringByExpandingTildeInPath]];
		return NO;
	}
	
	NSDictionary *templateDict = [NSDictionary dictionaryWithContentsOfFile:productPath];
	keyArray = [NSMutableArray arrayWithArray:[templateDict objectForKey:@"Keys"]];
	valueArray = [NSMutableArray arrayWithArray:[templateDict objectForKey:@"Values"]];
	[licenseExtensionField setStringValue:[templateDict objectForKey:@"Extension"]];
	[saveDirectoryField setStringValue:[templateDict objectForKey:@"Save Directory"]];
	
	if (![keyArray count])
		[generateLicenseButton setEnabled:NO];
	
	return YES;
}

#pragma mark Product Selection

- (void)newProductSelected
{
		
	// Enable everything except the remove button
	[addButton setEnabled:YES];
	[generateLicenseButton setEnabled:YES];
	[editExtensionButton setEnabled:YES];
	[editSaveDirectoryButton setEnabled:YES];
		
	// No template and a product, i.e. new product
	if (![self loadLicenseTemplate] && [productController currentProduct]) {
		// Default values
		keyArray = [NSMutableArray arrayWithObjects:@"Name", @"Email", nil];
		valueArray = [NSMutableArray arrayWithObjects:@"User", @"user@email.com", nil];
	}
	// No product
	else if (![productController currentProduct] ) {
		// Disable everything
		[addButton setEnabled:NO];
		[removeButton setEnabled:NO];
		[generateLicenseButton setEnabled:NO];
		[editExtensionButton setEnabled:NO];
		[editSaveDirectoryButton setEnabled:NO];
		
		[licenseExtensionField setStringValue:@""];
		[saveDirectoryField setStringValue:@""];
		
		keyArray = [NSMutableArray array];
		valueArray = [NSMutableArray array];
	}
	
	[keyValueTable reloadData];
}

#pragma mark Interface

- (IBAction)editLicenseExtension:(id)sender
{
	[licenseExtensionEditField setStringValue:[licenseExtensionField stringValue]];
	[NSApp beginSheet:licenseExtensionSheet modalForWindow:[NSApp keyWindow]
		   modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (IBAction)editSaveDirectory:(id)sender
{
	// Run the selection panel
	NSOpenPanel *selectPanel = [NSOpenPanel openPanel];
	[selectPanel setCanChooseFiles:NO];
	[selectPanel setCanChooseDirectories:YES];
	[selectPanel setAllowsMultipleSelection:NO];
	[selectPanel setPrompt:@"Select"];
	[selectPanel setTitle:@"Select Directory"];
	if ([selectPanel runModal] == NSFileHandlingPanelCancelButton)
		return;
	
	[saveDirectoryField setStringValue:[[selectPanel URL] path]];
}

- (IBAction)sheetOK:(id)sender
{
	[NSApp endSheet:licenseExtensionSheet];
    [licenseExtensionSheet orderOut:self];
	
	[licenseExtensionField setStringValue:[licenseExtensionEditField stringValue]];
}

- (IBAction)sheetCancel:(id)sender
{
	[NSApp endSheet:licenseExtensionSheet];
    [licenseExtensionSheet orderOut:self];
}

- (IBAction)addKeyValue:(id)sender
{
	[keyArray addObject:@"New Key"];
	[valueArray addObject:@"Undefined"];
	
	[keyValueTable reloadData];
	
	[generateLicenseButton setEnabled:YES];
}

- (IBAction)removeKeyValue:(id)sender
{
	if ([keyValueTable selectedRow] == -1)
		return;
	else
		[keyValueTable deleteItemAtIndex:[keyValueTable selectedRow]];
}

#pragma mark AQTableView Delegate Methods

- (void)deleteItemAtIndex:(int)row
{
	[keyArray removeObjectAtIndex:row];
	[valueArray removeObjectAtIndex:row];
	
	// Make sure we don't lose a reference to the arrays
	if ([keyArray count] == 0)
		;
	if ([valueArray count] == 0)
		;
	
	[keyValueTable reloadData];
	[keyValueTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row-1] byExtendingSelection:NO];
	
	if ([keyArray count] == 0)
		[generateLicenseButton setEnabled:NO];
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	if ([keyArray count] <= [valueArray count])
		return [keyArray count];
	else
		return [valueArray count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if ([[tableColumn identifier] isEqualToString:@"keyColumn"])
		return [keyArray objectAtIndex:row];
	else
		return [valueArray objectAtIndex:row];
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    if (!object)
		return;
		
	if ([[tableColumn identifier] isEqualToString:@"keyColumn"] && [object isEqualToString:@"Signature"]) {
		NSRunAlertPanel(@"Signature is a reserved key-value pair", @"Please choose another key name.", @"OK", nil, nil);
		return;
	}
	
	if ([[tableColumn identifier] isEqualToString:@"keyColumn"])
		[keyArray replaceObjectAtIndex:row withObject:object];
	else
		[valueArray replaceObjectAtIndex:row withObject:object];
	
	[keyValueTable reloadData];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	if ([keyValueTable selectedRow] == -1)
		[removeButton setEnabled:NO];
	else
		[removeButton setEnabled:YES];
}

@end
