/* InfoController */

#import <Cocoa/Cocoa.h>

@interface InfoController : NSWindowController
{
	IBOutlet NSView *licenseInfoView;
	IBOutlet NSWindow *licenseWindow;
	IBOutlet NSTableView *keyValueInfoTable;
	IBOutlet NSTextField *licenseValidField;
	IBOutlet NSTextField *hashField;
	
	NSMutableArray *keyInfoArray;
	NSMutableArray *valueInfoArray;
	BOOL isLicenseValid;
	NSString *licenseValidForProduct;
	NSString *hash;
}

- (BOOL)readLicenseAtPath:(NSString*)licensePath;

@end