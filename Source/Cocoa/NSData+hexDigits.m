//
//  NSData+hexDigits.m
//  AquaticPrime Developer
//
//  Created by Geode on 07/09/2012.
//
//

#import "NSData+hexDigits.h"

@implementation NSData (hexDigits)

+ (NSData*)dataWithHexDigitRepresentation:(NSString*)hexDigitString {
    NSUInteger textLength = [hexDigitString length];
    NSAssert(textLength % 2 == 0, @"Expected an even count of hex digits");
    NSMutableData *data = [NSMutableData dataWithCapacity:textLength/2];
    NSRange range = NSMakeRange(0, 2);
    unsigned int uintValue = 0;
    uint8_t byteValue = 0;
    for (range.location = 0; range.location < textLength; range.location+=2) {
        NSScanner *scanner = [NSScanner scannerWithString:[hexDigitString substringWithRange:range]];
        if ([scanner scanHexInt:&uintValue]) {
            byteValue = (uint8_t)uintValue;
            [data appendBytes:&byteValue length:1];
        }
        else {
            // Failed to convert (bad hex digit?)
            return nil;
        }
    }
    return data;
}

- (NSString*)hexDigitRepresentation {
    uint8_t *rawBytes = (uint8_t*)[self bytes];
    NSUInteger byteIndex = 0, byteLength = [self length];
    
    NSMutableString *hexRepresentation = [NSMutableString stringWithCapacity:byteLength*2];
    for (byteIndex = 0; byteIndex < byteLength; byteIndex++) {
        [hexRepresentation appendFormat:@"%02x", rawBytes[byteIndex]];
    }
    return hexRepresentation;
}

@end
