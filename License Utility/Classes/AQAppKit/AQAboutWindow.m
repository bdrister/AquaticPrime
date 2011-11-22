#import "AQAboutWindow.h"

@implementation AQAboutWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    AQAboutWindow *result = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    [result setBackgroundColor: [NSColor clearColor]];
    [result setLevel: NSStatusWindowLevel];
    [result setOpaque:NO];
    [result setHasShadow:YES];
	[result setDelegate:self];
    return result;
}

- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)becomeFirstResponder
{
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	[self orderOut:self];
}

- (void)keyDown:(NSEvent *)theEvent
{
	[self orderOut:self];
}

- (void)windowDidResignKey:(NSNotification *)aNotification
{
	[self orderOut:self];
}

@end
