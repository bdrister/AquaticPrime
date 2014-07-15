/* MainController */

#import <Cocoa/Cocoa.h>
@class InfoController;
@class AboutController;

@interface MainController : NSObject<NSApplicationDelegate>
{
	NSWindow *mainWindow;
	InfoController *infoController;
	AboutController *aboutController;
	NSWindow *prefsWindow;
}
@property (nonatomic, strong) IBOutlet NSWindow *prefsWindow;
- (IBAction)showLicenseInfoWindow:(id)sender;
- (IBAction)closeWindow:(id)sender;
- (IBAction)showPreferences:(id)sender;
@end
