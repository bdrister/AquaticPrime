//
//  NSData+hexDigits.h
//  AquaticPrime Developer
//
//  Created by Geode on 07/09/2012.
//
//

#import <Foundation/Foundation.h>

@interface NSData (hexDigits)

+ (NSData*)dataWithHexDigitRepresentation:(NSString*)hexDigitString;

- (NSString*)hexDigitRepresentation;


@end
