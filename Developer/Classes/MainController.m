#import "MainController.h"
#import "InfoController.h"
#import "AboutController.h"

@implementation MainController

- (void)awakeFromNib
{
	[mainWindow makeKeyAndOrderFront:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
	return YES;
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	if ([[[aNotification object] frameAutosaveName] isEqualToString:@"mainWindow"])
		[NSApp terminate:self];
}

- (IBAction)showAboutBox:(id)sender
{
	if (!aboutController) {
		aboutController = [[AboutController alloc] init];
	}
	
	[[aboutController window] makeKeyAndOrderFront:self];
}

- (IBAction)showLicenseInfoWindow:(id)sender
{
	if (!infoController) {
		infoController = [[InfoController alloc] init];
	}
	[infoController showWindow:self];
}

- (IBAction)closeWindow:(id)sender
{
	[[NSApp keyWindow] orderOut:self];
}

- (BOOL)validateMenuItem:(NSMenuItem *)aMenuItem
{
	if ([[aMenuItem title] isEqualToString:@"Close"]) {
		if (![NSApp keyWindow])
			return NO;
	}
	
	return YES;
}

@end
