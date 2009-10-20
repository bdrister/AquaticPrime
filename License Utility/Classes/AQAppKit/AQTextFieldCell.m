#import "AQTextFieldCell.h"

@implementation AQTextFieldCell

// Deal with drawing the text inside the cell ourselves
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
   // First get the string and string attributes
   NSString *string = [self stringValue];
   NSMutableDictionary *attribs = [[[self attributedStringValue] attributesAtIndex:0 effectiveRange:nil] mutableCopy];
   
   // If the cell is selected and its control view is the first responder, draw the text white
   if ([self isHighlighted])
       [attribs setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
   
   // Then adjust the drawing rectangle and draw the text so that it is centered vertically
   NSSize stringSize = [string sizeWithAttributes:attribs];
   cellFrame.origin.x += 4.0;
   cellFrame.size.width -= 4.0;
   cellFrame.origin.y += (cellFrame.size.height - stringSize.height) / 2;
   cellFrame.size.height = stringSize.height;
   [string drawInRect:cellFrame withAttributes:attribs];
   [attribs release];
}

@end
