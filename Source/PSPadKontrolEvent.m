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

#import "PSPadKontrolEvent.h"


@implementation PSPadKontrolEvent
@synthesize device=_device, type=_type, velocity=_velocity, values=_values, numberOfValues=_numberOfValues, affected_entity_code=_affected_entity_code, affectedPad=_affectedPad;

+ (PSPadKontrolEvent *)eventWithDevice:(PSPadKontrol *)inDevice
                                  type:(PSPadKontrolEventType)inType
                              velocity:(PSPadKontrolVelocity)inVelocity 
                                values:(PSPadKontrolValue *)inValues
                        numberOfValues:(NSUInteger)numberOfInValues
                           affectedPad:(NSInteger)inAffectedPad
                    affectedEntityCode:(uint8_t)inAffected_entity_code {
	return [[[self alloc] initWithDevice:inDevice
                                  type:inType
                              velocity:inVelocity
                                values:inValues
                        numberOfValues:numberOfInValues
                           affectedPad:inAffectedPad
                    affectedEntityCode:inAffected_entity_code] autorelease];
}
- (id)initWithDevice:(PSPadKontrol *)inDevice
                type:(PSPadKontrolEventType)inType
            velocity:(PSPadKontrolVelocity)inVelocity 
              values:(PSPadKontrolValue *)inValues
      numberOfValues:(NSUInteger)numberOfInValues
         affectedPad:(NSInteger)inAffectedPad
	affectedEntityCode:(uint8_t)inAffected_entity_code; {
	if(!(self = [super init]))
		return nil;
	_device = [inDevice retain];
	_type = inType;
	_velocity = inVelocity;
	_values = malloc(sizeof(PSPadKontrolValue)*numberOfInValues);
	memcpy(_values, inValues, sizeof(PSPadKontrolValue)*numberOfInValues);
	_numberOfValues = numberOfInValues;
	_affectedPad = inAffectedPad;
	_affected_entity_code = inAffected_entity_code;
	
	return self;
}
- (void)dealloc {
	[_device release];
  free(_values);
	[super dealloc];
}

- (NSString *)description {
	return [[super description] stringByAppendingFormat:@"Type: %d Velocity: %d", _type, _velocity];
}
@end
