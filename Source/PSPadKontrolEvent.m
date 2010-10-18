//
//  PSPadKontrolEvent.m
//  sekwenser
//
//  Created by フィヨ on 10/10/11.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import "PSPadKontrolEvent.h"


@implementation PSPadKontrolEvent
@synthesize type, velocity, values, numberOfValues, affected_entity_code, affectedPad;

+ (PSPadKontrolEvent *)eventWithType:(PSPadKontrolEventType)inType
														velocity:(PSPadKontrolVelocity)inVelocity 
															values:(PSPadKontrolValue *)inValues
											numberOfValues:(NSUInteger)numberOfInValues
												 affectedPad:(NSInteger)inAffectedPad
									affectedEntityCode:(uint8_t)inAffected_entity_code
{
	return [[[self alloc] initWithType:inType
														velocity:inVelocity
															values:inValues
											numberOfValues:numberOfInValues
												 affectedPad:inAffectedPad
									affectedEntityCode:inAffected_entity_code] autorelease];
}
- (id)initWithType:(PSPadKontrolEventType)inType
					velocity:(PSPadKontrolVelocity)inVelocity 
						values:(PSPadKontrolValue *)inValues
		numberOfValues:(NSUInteger)numberOfInValues
			 affectedPad:(NSInteger)inAffectedPad
affectedEntityCode:(uint8_t)inAffected_entity_code
{
	if(!(self = [super init]))
		return nil;
	
	type = inType;
	velocity = inVelocity;
	values = malloc(sizeof(PSPadKontrolValue)*numberOfInValues);
	memcpy(values, inValues, sizeof(PSPadKontrolValue)*numberOfInValues);
	numberOfValues = numberOfInValues;
	affectedPad = inAffectedPad;
	affected_entity_code = inAffected_entity_code;
	
	return self;
}

- (NSString *)description
{
	return [[super description] stringByAppendingFormat:@"Type: %d Velocity: %d", self.type, self.velocity];
}
- (void)dealloc
{
	free(values);
	[super dealloc];
}
@end
