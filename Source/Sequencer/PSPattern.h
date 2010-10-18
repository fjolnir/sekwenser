//
//  PSPattern.h
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PSPattern : NSObject<NSCoding, NSCopying> {
	NSMutableArray *steps;

	uint8_t note;
	BOOL muted;
}
@property(readwrite, retain) NSMutableArray *steps;
@property(readwrite, assign) uint8_t note;
@property(readwrite, assign) BOOL muted;

+ (PSPattern *)emptyPatternWithNote:(uint8_t)inNote numberOfSteps:(NSUInteger)numberOfSteps;
@end
