////////////////////////////////////////////////////////////////////////////////////////////
//
//  PSPadKontrolEvent
//
////////////////////////////////////////////////////////////////////////////////////////////
//
// Copyright (c) 2010, Fjölnir Ásgeirsson
// 
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or without modification, 
// are permitted provided that the following conditions are met:
// 
// Redistributions of source code must retain the above copyright notice, this list of conditions
// and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this list of
// conditions and the following disclaimer in the documentation and/or other materials provided with 
// the distribution.
// Neither the name of Fjölnir Ásgeirsson, ninja kitten nor the names of its contributors may be 
// used to endorse or promote products derived from this software without specific prior written permission.
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
// PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
// LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


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
