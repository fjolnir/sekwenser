//
//  PSPatternSet.m
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import "PSPatternSet.h"
#import "PSPattern.h"

@implementation PSPatternSet
@synthesize activePattern, patterns, mutedSteps;

+ (PSPatternSet *)patternSetWithEmptyPatterns:(NSUInteger)numberOfPatterns
																activePattern:(NSUInteger)activePatternIndex
{
	PSPatternSet *ret = [[self alloc] init];
	ret.patterns = [NSMutableArray array];
	
	PSPattern *currPat;
	for(int i = 0; i < numberOfPatterns; ++i)
	{
		currPat = [PSPattern emptyPatternWithNote:i+1 channel:1 numberOfSteps:16];
		if(i == activePatternIndex)
			ret.activePattern = currPat;
		[ret.patterns addObject:currPat];
	}
	return [ret autorelease];
}

- (id)init
{
	if(!(self = [super init]))
		return nil;
	
	self.mutedSteps = [NSMutableIndexSet indexSet];
	
	return self;
}
// Not a true 'copy' but rather we copy the patterns and mutes etc from one to this pattern set
- (void)copyPatternSet:(PSPatternSet *)patternSetToCopy
{
	int i = 0;
	PSPattern *currentCopy;
	PSPattern *toBeOverWritten;
	for(PSPattern *pattern in patternSetToCopy.patterns)
	{
		currentCopy = [pattern copy];
		toBeOverWritten = [self.patterns objectAtIndex:i];
		currentCopy.note = pattern.note;
		[self.patterns replaceObjectAtIndex:i withObject:currentCopy];
		[currentCopy release];
		++i;
	}
	self.mutedSteps = [patternSetToCopy.mutedSteps mutableCopy];
	self.activePattern = [self.patterns objectAtIndex:[patternSetToCopy.patterns indexOfObject:patternSetToCopy.activePattern]];
}

- (id)copyWithZone:(NSZone *)zone
{
	PSPatternSet *copy = [[PSPatternSet alloc] init];
	copy.patterns = [[[NSMutableArray alloc] initWithArray:self.patterns copyItems:YES] autorelease];
	copy.activePattern = [copy.patterns objectAtIndex:[self.patterns indexOfObject:self.activePattern]];
	copy.mutedSteps = [self.mutedSteps mutableCopyWithZone:zone];
	
	return copy;
}

- (id)initWithCoder:(NSCoder *)coder
{
	if(!(self = [super init]))
		return nil;
	
	self.patterns = [coder decodeObjectForKey:@"patterns"];
	self.activePattern = [self.patterns objectAtIndex:[coder decodeIntForKey:@"activePatternIndex"]];
	self.mutedSteps = [coder decodeObjectForKey:@"mutedSteps"];
	
	return self;
}
- (void)encodeWithCoder:(NSCoder *)coder
{
	[coder encodeObject:self.patterns forKey:@"patterns"];
	[coder encodeInt:[self.patterns indexOfObject:self.activePattern] forKey:@"activePatternIndex"];
	[coder encodeObject:mutedSteps forKey:@"mutedSteps"];
}
@end
