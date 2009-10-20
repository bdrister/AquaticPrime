//
// LicenseController.m
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
	keyArray = [[NSMutableArray array] retain];
	valueArray = [[NSMutableArray array] retain];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newProductSelected) name:@"ProductSelected" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveLicenseTemplate:) name:@"ProductWillBeSelected" object:nil];

	return [super init];
}
 
- (void)dealloc
{
	[keyArray release];
	[valueArray release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
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
	NSString *supportDir = [@"~/Library/Application Support/Aquatic" stringByExpandingTildeInPath];
	NSString *licenseDir = [supportDir stringByAppendingString:@"/Generated Licenses"];
	BOOL isDir;
	
	// The ~/Library/Application Support/Aquatic/ folder doesn't exist yet
	if (![fm fileExistsAtPath:supportDir isDirectory:&isDir])
	{
		// The support path leads to a file! Bad! This shouldn't happen ever!!
		if (!isDir)
			[fm removeFileAtPath:supportDir handler:nil];
		
		// Create the ~/Library/Application Support/Aquatic/ directory
		[fm createDirectoryAtPath:supportDir attributes:nil];
	}

	// The ~/Library/Application Support/Aquatic/Generated Licenses folder doesn't exist yet
	if  (![fm fileExistsAtPath:licenseDir isDirectory:&isDir])
	{
		// The licenses path leads to a file! Bad! This shouldn't happen ever!!
		if (!isDir)
			[fm removeFileAtPath:licenseDir handler:nil];
			
		// Create the product key directory
		[fm createDirectoryAtPath:licenseDir attributes:nil];
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
	int index;
	if ([anObject respondsToSelector:@selector(object)] && [[anObject object] respondsToSelector:@selector(selectedRow)])
		index = [[anObject object] selectedRow];
	else
		return;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = [@"~/Library/Application Support/Aquatic" stringByExpandingTildeInPath];
	NSString *templateDir = [supportDir stringByAppendingString:@"/License Templates"];
	NSString *productPath = [templateDir stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", [productController productAtIndex:index]]];
	BOOL isDir;
	
	// Save this way to preserve the order of items
	NSDictionary *templateDict = [NSDictionary dictionaryWithObjectsAndKeys:keyArray, @"Keys", 
																			valueArray, @"Values", 
																			[licenseExtensionField stringValue], @"Extension",
																			[saveDirectoryField stringValue], @"Save Directory", nil];
	
	// The ~/Library/Application Support/Aquatic/ folder doesn't exist yet
	if (![fm fileExistsAtPath:supportDir isDirectory:&isDir])
	{
		// The support path leads to a file! Bad! This shouldn't happen ever!!
		if (!isDir)
			[fm removeFileAtPath:supportDir handler:nil];
		
		// Create the ~/Library/Application Support/Aquatic/ directory
		[fm createDirectoryAtPath:supportDir attributes:nil];
	}
	
	// The ~/Library/Application Support/Aquatic/License Templates folder doesn't exist yet
	if  (![fm fileExistsAtPath:templateDir isDirectory:&isDir])
	{
		// The template path leads to a file! Bad! This shouldn't happen ever!!
		if (!isDir)
			[fm removeFileAtPath:templateDir handler:nil];
			
		// Create the product key directory
		[fm createDirectoryAtPath:templateDir attributes:nil];
	}
	
	[templateDict writeToFile:productPath atomically:YES];

	return;
}
 
- (BOOL)loadLicenseTemplate
{
	if (![productController currentProduct])
		return NO;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = [@"~/Library/Application Support/Aquatic" stringByExpandingTildeInPath];
	NSString *templateDir = [supportDir stringByAppendingString:@"/License Templates"];
	NSString *productPath = [templateDir stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", [productController currentProduct]]];

	if (![fm fileExistsAtPath:productPath])
	{
		[licenseExtensionField setStringValue:@"plist"];
		[licenseExtensionEditField setStringValue:@"plist"];
		[saveDirectoryField setStringValue:[@"~/Documents" stringByExpandingTildeInPath]];
		return NO;
	}
	
	NSDictionary *templateDict = [NSDictionary dictionaryWithContentsOfFile:productPath];
	keyArray = [[NSMutableArray arrayWithArray:[templateDict objectForKey:@"Keys"]] retain];
	valueArray = [[NSMutableArray arrayWithArray:[templateDict objectForKey:@"Values"]] retain];
	[licenseExtensionField setStringValue:[templateDict objectForKey:@"Extension"]];
	[saveDirectoryField setStringValue:[templateDict objectForKey:@"Save Directory"]];
	
	if (![keyArray count])
		[generateLicenseButton setEnabled:NO];
	
	return YES;
}

#pragma mark Product Selection

- (void)newProductSelected
{
	if (keyArray)
		[keyArray release];
	if (valueArray)
		[valueArray release];
		
	// Enable everything except the remove button
	[addButton setEnabled:YES];
	[generateLicenseButton setEnabled:YES];
	[editExtensionButton setEnabled:YES];
	[editSaveDirectoryButton setEnabled:YES];
		
	// No template and a product, i.e. new product
	if (![self loadLicenseTemplate] && [productController currentProduct]) {
		// Default values
		keyArray = [[NSMutableArray arrayWithObjects:@"Name", @"Email", nil] retain];
		valueArray = [[NSMutableArray arrayWithObjects:@"User", @"user@email.com", nil] retain];
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
		
		keyArray = [[NSMutableArray array] retain];
		valueArray = [[NSMutableArray array] retain];
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
	
	[saveDirectoryField setStringValue:[[selectPanel filenames] objectAtIndex:0]];
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

#pragma mark TableView Delegate Methods

- (void)deleteItemAtIndex:(int)row
{
	[keyArray removeObjectAtIndex:row];
	[valueArray removeObjectAtIndex:row];
	
	// Make sure we don't lose a reference to the arrays
	if (![keyArray count])
		[keyArray retain];
	if (![valueArray count])
		[valueArray retain];
	
	[keyValueTable reloadData];
	[keyValueTable selectRow:row-1 byExtendingSelection:NO];
	
	if (![keyArray count])
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
