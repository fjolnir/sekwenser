//
//  PSStep.m
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import "PSStep.h"


@implementation PSStep
@synthesize enabled, velocity, noteOn;

+ (PSStep *)stepWithVelocity:(uint8_t)inVelocity
{
	PSStep *ret = [[self alloc] init];
	ret.velocity = inVelocity;
	
	return [ret autorelease];
}

- (id)copyWithZone:(NSZone *)zone
{
	PSStep *copy = [[PSStep stepWithVelocity:self.velocity] retain];
	copy.enabled = self.enabled;
	return copy;
}

- (id)initWithCoder:(NSCoder *)coder
{
	if(!(self = [super init]))
		return nil;
	
	self.enabled = [coder decodeBoolForKey:@"stepEnabled"];
	self.velocity = [coder decodeIntForKey:@"stepVelocity"];
	
	return self;
}
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeBool:self.enabled forKey:@"stepEnabled"];
	[coder encodeInt:self.velocity forKey:@"stepVelocity"];
}
@end
