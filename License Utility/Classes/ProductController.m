//
// ProductController.m
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

#import "ProductController.h"
#import "KeyController.h"
#import "AQTableView.h"

@implementation ProductController

#pragma mark Init

- (id)init
{
	productArray = [[[NSMutableArray alloc] init] retain];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadProducts) name:@"NewKeyGenerated" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveProducts:) name:@"NSApplicationWillTerminateNotification" object:nil];
	return [super init];
}

- (void)dealloc
{
	[productArray release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)awakeFromNib
{
	[self loadProducts];
}

- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem
{	
	if ([[aMenuItem title] isEqualToString:@"Duplicate"] || [[aMenuItem title] isEqualToString:@"Rename"]) {
		if (![productArray count])
			return NO;
	}
	
	return YES;
}

- (IBAction)saveProducts:(id)sender
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ProductWillBeSelected" object:productTable];
}

#pragma mark Load Project

- (void)loadProducts
{
	NSString *keyDir = [@"~/Library/Application Support/Aquatic/Product Keys" stringByExpandingTildeInPath];
	NSString *curPath;
	NSMutableArray *possibleproductArray = [NSMutableArray array];
	NSDirectoryEnumerator *pathEnum = [[NSFileManager defaultManager] enumeratorAtPath:keyDir];
	
	// Grab all the key paths
	if(pathEnum) {
		while ((curPath = [pathEnum nextObject])) {
			if ([[curPath pathExtension] isEqualToString:@"plist"])
				[possibleproductArray addObject:[keyDir stringByAppendingPathComponent:curPath]];
		}
	}
	
	// Determine if they are real keys
	NSEnumerator *keyEnum = [possibleproductArray objectEnumerator];
	NSString *curKey;
	NSDictionary *testDict;
	
	while ((curKey = [keyEnum nextObject])) {
		testDict = [NSDictionary dictionaryWithContentsOfFile:curKey];
		// If it has both public and private key, add it to the product list
		if ([[testDict allKeys] containsObject:@"Public Key"] && [[testDict allKeys] containsObject:@"Private Key"]) {
			if (![productArray containsObject:[[curKey lastPathComponent] stringByDeletingPathExtension]])
				[productArray addObject:[[curKey lastPathComponent] stringByDeletingPathExtension]];
			}
	}
	
	[productArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
	[productTable reloadData];
	
	if ([productArray count]) {
		[[NSNotificationCenter defaultCenter] postNotificationName:@"ProductSelected" object:nil];
		[removeButton setEnabled:YES];
	} 
	else {
		[removeButton setEnabled:NO];
	}
}

#pragma mark Add Project

- (IBAction)addNewProduct:(id)sender
{
	[nameField setStringValue:@"Untitled"];
	[NSApp beginSheet:newProductSheet modalForWindow:mainWindow modalDelegate:self didEndSelector:nil contextInfo:nil];
}

- (IBAction)duplicateProduct:(id)sender
{
	if (![self currentProduct])
		return;
	
	// This saves the current license template
	[self saveProducts:self];
	
	// Copy the files
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *oldProduct = [self currentProduct];
	
	// Figure out which copy we are on
	NSString *copy = @" Copy";
	int i = 1;
	while ([productArray containsObject:[oldProduct stringByAppendingString:copy]])
		copy = [NSString stringWithFormat:@" Copy %i", i++];
		
	NSString *oldTemplateProductPath = [[@"~/Library/Application Support/Aquatic/License Templates" stringByExpandingTildeInPath] stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", oldProduct]];
	NSString *newTemplateProductPath = [[@"~/Library/Application Support/Aquatic/License Templates" stringByExpandingTildeInPath] stringByAppendingString:[NSString stringWithFormat:@"/%@%@.plist", oldProduct, copy]];
	NSString *oldKeyProductPath = [[@"~/Library/Application Support/Aquatic/Product Keys" stringByExpandingTildeInPath] stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", oldProduct]];
	NSString *newKeyProductPath = [[@"~/Library/Application Support/Aquatic/Product Keys" stringByExpandingTildeInPath] stringByAppendingString:[NSString stringWithFormat:@"/%@%@.plist", oldProduct, copy]];

	[fm copyPath:oldTemplateProductPath toPath:newTemplateProductPath handler:nil];
	[fm copyPath:oldKeyProductPath toPath:newKeyProductPath handler:nil];
	
	[productArray addObject:[oldProduct stringByAppendingString:copy]];
	[productArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
	[productTable reloadData];
	// Select the copy
	[productTable selectRow:[productArray indexOfObject:[oldProduct stringByAppendingString:copy]] byExtendingSelection:NO];
}

- (IBAction)sheetOK:(id)sender
{
	[NSApp endSheet:newProductSheet];
    [newProductSheet orderOut:self];
	
	NSString *productName = [nameField stringValue];
	
	if ([productName isEqualToString:@""])
		return;
	
	[keyController generateKeyForProduct:productName];
	if ([productArray count]) {
		[productTable selectRow:[productArray indexOfObject:productName] byExtendingSelection:NO];
		[removeButton setEnabled:YES];
	}
}

- (IBAction)sheetCancel:(id)sender
{
	[NSApp endSheet:newProductSheet];
    [newProductSheet orderOut:self];
	[nameField setStringValue:@""];
}

#pragma mark Remove Project

- (IBAction)removeProduct:(id)sender
{
	if ([productTable selectedRow] != -1)
		[productTable deleteItemAtIndex:[productTable selectedRow]];
	
	if (![productArray count])
		[removeButton setEnabled:NO];
}

#pragma mark Product Names

- (NSArray*)allProducts
{
	return productArray;
}

- (NSString *)currentProduct
{
	int index = [productTable selectedRow];
	
	if (index == -1)
		return nil;
	else
		return [productArray objectAtIndex:index];
}

- (NSString *)productAtIndex:(int)index
{
	if (index == -1)
		return nil;
	else
		return [productArray objectAtIndex:index];
}

- (IBAction)renameProduct:(id)sender
{
	[productTable editColumn:0 row:[productTable selectedRow] withEvent:nil select:YES];
}

#pragma mark TableView Delegate Methods

- (void)deleteItemAtIndex:(int)index
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *supportDir = [@"~/Library/Application Support/Aquatic" stringByExpandingTildeInPath];
	NSString *product = [self productAtIndex:index];
	
	if (NSRunAlertPanel([NSString stringWithFormat:@"Are you sure you want to delete %@?", product],
						@"This cannot be undone.", @"OK", @"Cancel", nil) == NSAlertAlternateReturn)
		return;
	
	[fm removeFileAtPath:[supportDir stringByAppendingString:[NSString stringWithFormat:@"/Product Keys/%@.plist", product]] handler:nil];
	[fm removeFileAtPath:[supportDir stringByAppendingString:[NSString stringWithFormat:@"/License Templates/%@.plist", product]] handler:nil];
	[productArray removeObjectAtIndex:index];
		
	[productTable reloadData];
	[productTable selectRow:index-1 byExtendingSelection:NO];
	//[[NSNotificationCenter defaultCenter] postNotificationName:@"ProductSelected" object:productTable];
}

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [productArray count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
	return [productArray objectAtIndex:row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ProductSelected" object:aNotification];
}

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)tableView
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ProductWillBeSelected" object:tableView];
	return YES;
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(int)row
{
    // Don't allow "" as a name
	if (!object || [object isEqualToString:@""])
		return;
	
	// Move the keys to the new path
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *oldProductPath = [[@"~/Library/Application Support/Aquatic/Product Keys" stringByExpandingTildeInPath] 
							stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", [productArray objectAtIndex:row]]];

	NSString *newProductPath = [[@"~/Library/Application Support/Aquatic/Product Keys" stringByExpandingTildeInPath] 
							stringByAppendingString:[NSString stringWithFormat:@"/%@.plist", object]];
							
	[fm movePath:oldProductPath toPath:newProductPath handler:nil];
	
	// Change the name
	[productArray replaceObjectAtIndex:row withObject:object];
	[productArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
	[productTable reloadData];
}

@end
