//
//  PSStep.h
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PSStep : NSObject<NSCoding, NSCopying> {
	BOOL enabled;
	uint8_t velocity; // MIDI properties
	
	BOOL noteOn;
}
@property(readwrite, assign) BOOL enabled, noteOn;
@property(readwrite, assign) uint8_t velocity;

+ (PSStep *)stepWithVelocity:(uint8_t)inVelocity;
@end
