/* MainController */

#import <Cocoa/Cocoa.h>
@class InfoController;
@class AboutController;

@interface MainController : NSObject
{
	NSWindow *mainWindow;
	InfoController *infoController;
	AboutController *aboutController;
}

- (IBAction)showLicenseInfoWindow:(id)sender;
- (IBAction)closeWindow:(id)sender;

@end
