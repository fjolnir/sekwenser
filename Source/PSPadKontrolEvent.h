//
//  PSPadKontrolEvent.h
//  sekwenser
//
//  Created by フィヨ on 10/10/11.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PSPadKontrol.h"

typedef struct _PSPadKontrolPadTouch
{
	NSUInteger padNumber; // 0-16
	BOOL releaseEvent;
} PSPadKontrolPadTouch;

typedef enum {
	// When a pad is struck. Has velocity
	PSPadKontrolPadPressEventType      = 1,
	PSPadKontrolPadReleaseEventType    = 2,
	PSPadKontrolButtonPressEventType   = 3,
	PSPadKontrolButtonReleaseEventType = 4,
	PSPadKontrolKnobTurnEventType      = 5,
	PSPadKontrolEncoderTurnEventType   = 6,
	PSPadKontrolXYPadPressEventType    = 7,
	PSPadKontrolXYPadReleaseEventType  = 8,
	// When the finger is moved on the XY pad, has two values, X and Y positions
	PSPadKontrolXYPadMoveEventType     = 9,
	PSPadKontrolEnteredNativeMode      = 10
} PSPadKontrolEventType;



@interface PSPadKontrolEvent : NSObject {
	PSPadKontrolEventType type;
	PSPadKontrolVelocity velocity; // Only set for pad events
	
	PSPadKontrolValue *values;
	NSUInteger numberOfValues;
	
	NSInteger affectedPad; // Only set for pad events
	uint8_t affected_entity_code;
}
@property(readonly) PSPadKontrolEventType type;
@property(readonly) PSPadKontrolVelocity velocity;
@property(readonly) PSPadKontrolValue *values;
@property(readonly) NSUInteger numberOfValues;
@property(readonly) NSInteger affectedPad;
@property(readonly) uint8_t affected_entity_code;
+ (PSPadKontrolEvent *)eventWithType:(PSPadKontrolEventType)inType
														velocity:(PSPadKontrolVelocity)inVelocity 
															values:(PSPadKontrolValue *)inValues
											numberOfValues:(NSUInteger)numberOfInValues
												 affectedPad:(NSInteger)inAffectedPad
									affectedEntityCode:(uint8_t)inAffected_entity_code;
- (id)initWithType:(PSPadKontrolEventType)inType
					velocity:(PSPadKontrolVelocity)inVelocity 
						values:(PSPadKontrolValue *)inValues
		numberOfValues:(NSUInteger)numberOfInValues
			 affectedPad:(NSInteger)inAffectedPad
	affectedEntityCode:(uint8_t)inAffected_entity_code;
@end
