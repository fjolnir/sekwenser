////////////////////////////////////////////////////////////////////////////////////////////
//
//  PSPatternSet
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


#import "PSPatternSet.h"
#import "PSPattern.h"

@implementation PSPatternSet
@synthesize activePattern=_activePattern, patterns=_patterns, mutedSteps=_mutedSteps;

+ (PSPatternSet *)patternSetWithEmptyPatterns:(NSUInteger)numberOfPatterns
																activePattern:(NSUInteger)activePatternIndex {
	PSPatternSet *ret = [[self alloc] init];
	ret.patterns = [NSMutableArray array];
	
	PSPattern *currPat;
	for(int i = 0; i < numberOfPatterns; ++i) {
		currPat = [PSPattern emptyPatternWithNote:i+1 channel:1 numberOfSteps:16];
		if(i == activePatternIndex)
			ret.activePattern = currPat;
		[ret.patterns addObject:currPat];
	}
	return [ret autorelease];
}

- (id)init {
	if(!(self = [super init]))
		return nil;
	
	self.mutedSteps = [NSMutableIndexSet indexSet];
	
	return self;
}
- (void)dealloc {
  [_patterns release];
  [_activePattern release];
  [_mutedSteps release];
  
  [super dealloc];
}

// Not a true 'copy' but rather we copy the patterns and mutes etc from one to this pattern set
- (void)copyPatternSet:(PSPatternSet *)patternSetToCopy {
	int i = 0;
	PSPattern *currentCopy;
	for(PSPattern *pattern in patternSetToCopy.patterns) {
		currentCopy = [pattern copy];
		currentCopy.note = pattern.note;
		[_patterns replaceObjectAtIndex:i withObject:currentCopy];
		[currentCopy release];
		++i;
	}
	self.mutedSteps = [[patternSetToCopy.mutedSteps mutableCopy] autorelease];
	self.activePattern = [_patterns objectAtIndex:[patternSetToCopy.patterns indexOfObject:patternSetToCopy.activePattern]];
}

- (id)copyWithZone:(NSZone *)zone {
	PSPatternSet *copy = [[PSPatternSet alloc] init];
	copy.patterns = [[[NSMutableArray alloc] initWithArray:_patterns copyItems:YES] autorelease];
	copy.activePattern = [copy.patterns objectAtIndex:[_patterns indexOfObject:_activePattern]];
	copy.mutedSteps = [_mutedSteps mutableCopyWithZone:zone];
	
	return copy;
}

- (id)initWithCoder:(NSCoder *)coder {
	if(!(self = [super init]))
		return nil;
	
	self.patterns = [coder decodeObjectForKey:@"patterns"];
	self.activePattern = [self.patterns objectAtIndex:[coder decodeIntForKey:@"activePatternIndex"]];
	self.mutedSteps = [coder decodeObjectForKey:@"mutedSteps"];
	
	return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
	[coder encodeObject:_patterns forKey:@"patterns"];
	[coder encodeInt:[_patterns indexOfObject:_activePattern] forKey:@"activePatternIndex"];
	[coder encodeObject:_mutedSteps forKey:@"mutedSteps"];
}
@end
