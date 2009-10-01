#import "AQAboutView.h"

@implementation AQAboutView

-(void)awakeFromNib
{
    aboutImage = [NSImage imageNamed:@"aboutbox"];
    [self setNeedsDisplay:YES];
}

-(void)drawRect:(NSRect)rect
{
    [[NSColor clearColor] set];
    NSRectFill([self frame]);

    [aboutImage compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];

	[[self window] invalidateShadow];
}

@end
