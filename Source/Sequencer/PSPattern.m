////////////////////////////////////////////////////////////////////////////////////////////
//
//  PSPattern
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

#import "PSPattern.h"
#import "PSStep.h"

@implementation PSPattern
@synthesize steps, note, channel, muted;
+ (PSPattern *)emptyPatternWithNote:(uint8_t)inNote channel:(uint8_t)inChannel numberOfSteps:(NSUInteger)numberOfSteps
{
	PSPattern *ret = [[self alloc] init];
	ret.note = inNote;
	ret.channel = inChannel;
	ret.steps   = [NSMutableArray array];
	
	for(int i = 0; i < numberOfSteps; ++i)
	{
		[ret.steps addObject:[PSStep stepWithVelocity:127]];
	}
	return [ret autorelease];
}

- (id)copyWithZone:(NSZone *)zone
{
	PSPattern *copy = [[PSPattern alloc] init];
	copy.steps = [[[NSMutableArray alloc] initWithArray:self.steps copyItems:YES] autorelease];
	copy.muted = self.muted;
	copy.note = self.note;
	copy.channel = self.channel;
	return copy;
}
- (id)initWithCoder:(NSCoder *)coder
{
	if(!(self = [super init]))
		return nil;
	
	self.steps = [coder decodeObjectForKey:@"steps"];
	self.note = [coder decodeIntForKey:@"note"];
	self.channel = [coder decodeIntForKey:@"channel"];
	self.muted = [coder decodeBoolForKey:@"muted"];
	
	return self;
}
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.steps forKey:@"steps"];
	[coder encodeInt:self.note forKey:@"note"];
	[coder encodeInt:self.channel forKey:@"channel"];
	[coder encodeBool:self.muted forKey:@"muted"];
}
@end