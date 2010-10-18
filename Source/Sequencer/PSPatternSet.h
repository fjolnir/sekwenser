//
//  PSPatternSet.h
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

// A group of patterns 

#import <Cocoa/Cocoa.h>

@class PSPattern;

@interface PSPatternSet : NSObject<NSCoding, NSCopying> {
	NSMutableArray *patterns;
	PSPattern *activePattern;
	
	NSMutableIndexSet *mutedSteps;
}
@property(readwrite, retain) NSMutableArray *patterns;
@property(readwrite, retain) PSPattern *activePattern;
@property(readwrite, retain) NSMutableIndexSet *mutedSteps;

+ (PSPatternSet *)patternSetWithEmptyPatterns:(NSUInteger)numberOfPatterns
																activePattern:(NSUInteger)activePatternIndex;
// Turns this set into an identical replica of another
- (void)copyPatternSet:(PSPatternSet *)patternSetToCopy;
@end
