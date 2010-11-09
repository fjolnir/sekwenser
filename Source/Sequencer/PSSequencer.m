////////////////////////////////////////////////////////////////////////////////////////////
//
//  PSSequencer
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


#import "PSClock.h"
#import "PSSequencer.h"
#import "PSPatternSet.h"
#import "PSPattern.h"
#import "PSStep.h"

#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSECombinationOutputStream.h"

#import "PadKontrolConstants.h"
#import "PSPadKontrol.h"
#import "PSPadKontrolEvent.h"

#import <mach/mach_time.h>

#define BUTTON_ON_CC_VALUE  127
#define BUTTON_OFF_CC_VALUE 0

static PSSequencer *sharedSequencer = nil;

@interface PSSequencer () // Private
- (void)displayCurrentNoteOnLED;
- (void)displayCurrentChannelOnLED;
- (void)transmitCC:(uint8_t)ccNumber channel:(uint8_t)channel value:(uint8_t)value;
@end
#pragma mark -

@implementation PSSequencer
@synthesize patternSets, numberOfSteps, activePatternSet, virtualOutputStream, currentStep, inPatternSetSequencingMode, patternSetSequencerSteps, currentPatSetSeqStep, patSetSeqViewPlaceMode, patSetSeq_stepToPlace, activeView, isModal, shiftButtonHeld, velocityEnabled, inNoteChangeMode, inChannelChangeMode, isActive;

+ (PSSequencer *)sharedSequencer
{
	if(!sharedSequencer)
		sharedSequencer = [[self alloc] init];
	
	return [[sharedSequencer retain] autorelease];
}

- (id)init
{
	if(!(self = [super init]))
		 return nil;
	
	[self resetSequencer];
	
	self.isActive = YES;
	self.activeView = PSSequencerSequencerView;
	self.velocityEnabled = NO;
	self.isModal = NO;
	
	midiMessagesAlive = [[NSMutableArray alloc] init];
	
	self.patternSetSequencerSteps = [NSMutableArray array];

	// Create the patterns
	self.patternSets = [NSMutableArray array];
	for(int i = 0; i < 16; ++i)
	{
		[self.patternSets addObject:[PSPatternSet patternSetWithEmptyPatterns:16 activePattern:0]];
	}
	self.activePatternSet = [self.patternSets objectAtIndex:0];
	
	//
	// Create a virtual output port (for sending notes to software)
	virtualOutputStream = [[SMVirtualOutputStream alloc] initWithName:@"sekwenser out" uniqueID:0];
	
	// Initialize the padkontrol
	[[[PSPadKontrol sharedPadKontrol] eventListeners] addObject:self];
	
	// Subscribe to the clock
	[[[PSClock globalClock] listeners] addObject:self];

	// Initialize the lights on the controller
	[self updateLights];
	
	return self;
}

- (void)resetSequencer
{
	self.currentStep = 0;
}

- (void)performStep
{	
	if(!isActive)
		return;
	NSMutableArray *midiMessages = [NSMutableArray array];
	
	PSPatternSet *patternSet = activePatternSet;
	// If in pattern set sequencing mode we play the currently active pattern set
	if(inPatternSetSequencingMode)
	{
		NSNumber *setIndex;
		if(currentPatSetSeqStep < [patternSetSequencerSteps count])
		{
			setIndex = [patternSetSequencerSteps objectAtIndex:currentPatSetSeqStep];
			patternSet = [patternSets objectAtIndex:[setIndex intValue]];
		}
		else
			return; // nothing to play
	}
	
	
	// Turn off all notes currently on
	for(SMVoiceMessage *aMsg in midiMessagesAlive)
	{
		[aMsg setStatus:SMVoiceMessageStatusNoteOff];
		[aMsg setDataByte2:0x00];
		[midiMessages addObject:aMsg];
	}
	[midiMessagesAlive removeAllObjects];
	
	Byte noteData[2] = {0x00, 0x00};
	for(PSPattern *pattern in patternSet.patterns)
	{
		// Send the note  for the active step
		PSStep *step = [pattern.steps objectAtIndex:currentStep];
		if(![patternSet.mutedSteps containsIndex:currentStep] && step.enabled)
		{	
			noteData[0] = pattern.note;
			noteData[1] = step.velocity;
			
			SMVoiceMessage *message = [SMVoiceMessage voiceMessageWithTimeStamp:SMGetCurrentHostTime()
																															 statusByte:SMVoiceMessageStatusNoteOn 
																																		 data:noteData 
																																	 length:2];
			[message setChannel:pattern.channel];
			[midiMessages addObject:message];
			[midiMessagesAlive addObject:message];
		}
	}
	[virtualOutputStream takeMIDIMessages:midiMessages];

	// If we're in the sequencer view we flash the current step
	// Unless it's muted, in which case it'll be skipped over
	if(self.activeView == PSSequencerSequencerView)
	{
		uint8_t lightCode = kPadOn_codes[currentStep];
		uint8_t lightState = kPad_shortOneshot_code+0x02; // add 2 to make the flash slightly longer
		[[PSPadKontrol sharedPadKontrol] controlLight:&lightCode state:&lightState];
	}
	else if(self.activeView == PSSequencerPatternSetSequencerView && self.inPatternSetSequencingMode)
	{
		// In pattern set sequencer view the blinking is handled, in updateLights
		// Reason being if we don't update/maintain the blink status after updating the lights, things'll look ugly
		[self updateLights];
	}
	
	// Increment the step
	if(++self.currentStep > 15)
	{
		self.currentStep = 0;
		if(++self.currentPatSetSeqStep >= [patternSetSequencerSteps count])
			self.currentPatSetSeqStep = 0;
	}
}

- (void)selectView:(PSSequencerView)view
{
	if(self.activeView == PSSequencerSequencerView || view == PSSequencerSequencerView)
	{
		self.activeView = view;
		[self updateLights];
	}
}

#pragma mark -
// PadKontrol communication
- (void)padKontrolEventReceived:(PSPadKontrolEvent *)event fromPadKontrol:(PSPadKontrol *)padKontrol
{
	//NSLog(@"Received event from PadKontrol: %@", event);

	PSPattern *activePattern = [activePatternSet activePattern];
	if([event type] == PSPadKontrolEnteredNativeMode)
	{
		[self selectView:PSSequencerSequencerView];
		self.isModal = NO;
		[self updateLights];
	}
	else if([event type] == PSPadKontrolPadPressEventType)
	{
		// If this is positive at the end of the block, the lights on the controller will be refreshed
		BOOL updateLights = YES;
		
		if(activeView == PSSequencerSequencerView)
		{
			PSStep *step = [[activePattern steps] objectAtIndex:event.affectedPad];
			
			step.enabled = !step.enabled;
			if(velocityEnabled)
				step.velocity = event.velocity;
			[[PSPadKontrol sharedPadKontrol] setLEDNumber:step.velocity blink:NO];
		}
		else if(activeView == PSSequencerPatternSelectView)
		{
			activePatternSet.activePattern = [activePatternSet.patterns objectAtIndex:event.affectedPad];
		}
		else if(activeView == PSSequencerStepMuteView)
		{
			if([activePatternSet.mutedSteps containsIndex:event.affectedPad])
				[activePatternSet.mutedSteps removeIndex:event.affectedPad];
			else
				[activePatternSet.mutedSteps addIndex:event.affectedPad];
			 
		}
		else if(activeView == PSSequencerPatternSetSelectView)
		{
			self.activePatternSet = [patternSets objectAtIndex:event.affectedPad];
		}
		else if(activeView == PSSequencerPatternCopyView)
		{
			updateLights = NO;
			if(!performingCopy)
			{
				uint8_t lightCode = kPadOn_codes[event.affectedPad];
				[[PSPadKontrol sharedPadKontrol] controlLight:&lightCode
																								state:(uint8_t *)&kPad_blink_code];
				currentCopySource = event.affectedPad;
				performingCopy = YES;
			}
			else
			{
				// Peform the actual copy
				PSPatternSet *setToCopy = [self.patternSets objectAtIndex:currentCopySource];
				PSPatternSet *destinationSet = [self.patternSets objectAtIndex:event.affectedPad];
				[destinationSet copyPatternSet:setToCopy];
				// Update the lights
				uint8_t sourceLightCode = kPadOn_codes[currentCopySource];
				uint8_t destLightCode   = kPadOn_codes[event.affectedPad];
				[[PSPadKontrol sharedPadKontrol] controlLight:&sourceLightCode
																								state:(uint8_t *)&kPad_lightOn_code];
				[[PSPadKontrol sharedPadKontrol] controlLight:&destLightCode
																								state:(uint8_t *)&kPad_shortOneshot_code];
				performingCopy = NO;
			}
		}
		else if(activeView == PSSequencerPatternSetSequencerView)
		{
			NSUInteger index = event.affectedPad;
			
			if(shiftButtonHeld)
			{
				if(index < [patternSetSequencerSteps count])
				{
					if(index == [patternSetSequencerSteps count]);
						 currentPatSetSeqStep = 0;
					[self.patternSetSequencerSteps removeObjectAtIndex:index];
				}
				self.patSetSeqViewPlaceMode = NO;
			}
			if(self.patSetSeqViewPlaceMode)
			{
				if(index < [patternSetSequencerSteps count])
					[patternSetSequencerSteps replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:self.patSetSeq_stepToPlace]];
				else if(index == [patternSetSequencerSteps count])
					[patternSetSequencerSteps addObject:[NSNumber numberWithInt:self.patSetSeq_stepToPlace]];
			}
			else
				self.patSetSeq_stepToPlace = index;
			self.patSetSeqViewPlaceMode = !self.patSetSeqViewPlaceMode;
			
			updateLights = YES;
		}
		
		if(updateLights) [self updateLights];
	}
	else if([event type] == PSPadKontrolButtonPressEventType)
	{
		uint8_t button_code = event.affected_entity_code;
		
		if(button_code == kSettingBtn_code)
		{
			[[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];
			shiftButtonHeld = YES;
			[self updateLights];
		}
		
		if(!isModal && !shiftButtonHeld)
		{
			// Light the button
			[[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];
			
			// Buttons in order of appearance on controller
			if(button_code == kSceneBtn_code)
			{
				[self selectView:PSSequencerPatternSelectView];
				self.isModal = YES;
			}
			else if(button_code == kMessageBtn_code)
			{
				[self selectView:PSSequencerPatternSetSelectView];
				self.isModal = YES;
			}
			else if(button_code == kHoldBtn_code)
			{
				[self selectView:PSSequencerPatternSetSequencerView];
				self.isModal = YES;
			}
			else if(button_code == kFlamBtn_code)
			{
				[self selectView:PSSequencerStepMuteView];
				self.isModal = YES;
			}
			else if(button_code == kRollBtn_code)
			{
				[self selectView:PSSequencerPatternCopyView];
				self.isModal = YES;
			}
			else
			{
				// Buttons not used by the sequencer transmit MIDI CC and don't care about modality/other buttons
				uint8_t buttonCh = 5;
				if(button_code == kXBtn_code)
					[self transmitCC:16 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kYBtn_code)
					[self transmitCC:17 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kPedalBtn_code)
					[self transmitCC:18 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kNoteCCBtn_code)
					[self transmitCC:19 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kMidiCHBtn_code)
					[self transmitCC:20 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kSWTypeBtn_code)
					[self transmitCC:21 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kRelValBtn_code)
					[self transmitCC:22 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kVelocityBtn_code)
					[self transmitCC:23 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kPortBtn_code)
					[self transmitCC:24 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kKnobAssignOneBtn_code)
					[self transmitCC:25 channel:buttonCh value:BUTTON_ON_CC_VALUE];
				if(button_code == kKnobAssignTwoBtn_code)
					[self transmitCC:26 channel:buttonCh value:BUTTON_ON_CC_VALUE];
			}			
		}
		// Shift mode (less often used functions)
		// In shift mode we only light the button if it has a function
		else if(shiftButtonHeld)
		{
			if(button_code == kNoteCCBtn_code)
			{
				self.inNoteChangeMode = YES;
				[self displayCurrentNoteOnLED];

				[[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];
			}
			else if(button_code == kMidiCHBtn_code)
			{
				self.inChannelChangeMode = YES;
				[self displayCurrentChannelOnLED];

				[[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];
			}
		}
	}
	else if([event type] == PSPadKontrolButtonReleaseEventType)
	{
		uint8_t button_code = event.affected_entity_code;
		
		// Turn the button back off
		[[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOff_code];
		
		if(button_code == kSettingBtn_code)
		{
			self.shiftButtonHeld = NO;
			[self updateLights];
		}
		// Return to sequencer mode
		else if((button_code == kSceneBtn_code  && activeView == PSSequencerPatternSelectView)
			 ||  (button_code == kFlamBtn_code    && activeView == PSSequencerStepMuteView)
			 ||  (button_code == kMessageBtn_code && activeView == PSSequencerPatternSetSelectView)
			 ||  (button_code == kRollBtn_code    && activeView == PSSequencerPatternCopyView)
			 ||  (button_code == kHoldBtn_code    && activeView == PSSequencerPatternSetSequencerView))
		{
			[self selectView:PSSequencerSequencerView];
			self.isModal = NO;
			performingCopy = NO;
		}
		else if(button_code == kNoteCCBtn_code)
		{
			self.inNoteChangeMode = NO;
			[[PSPadKontrol sharedPadKontrol] clearLED];
		}
		else if(button_code == kMidiCHBtn_code)
		{
			self.inChannelChangeMode = NO;
			[[PSPadKontrol sharedPadKontrol] clearLED];
		}
		else if(button_code == kFixedVelBtn_code)
		{
			self.velocityEnabled = !velocityEnabled;
			[self updateLights];
		}
		else if(button_code == kProgChangeBtn_code)
		{
			// Toggle pattern sequencing mode
			inPatternSetSequencingMode = !inPatternSetSequencingMode;
			currentPatSetSeqStep = 0;
			[self updateLights];
		}
		else
		{
			// Buttons not used by the sequencer transmit MIDI CC and don't care about modality/other buttons
			uint8_t buttonCh = 5;
			if(button_code == kXBtn_code)
				[self transmitCC:16 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kYBtn_code)
				[self transmitCC:17 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kPedalBtn_code)
				[self transmitCC:18 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kNoteCCBtn_code)
				[self transmitCC:19 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kMidiCHBtn_code)
				[self transmitCC:20 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kSWTypeBtn_code)
				[self transmitCC:21 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kRelValBtn_code)
				[self transmitCC:22 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kVelocityBtn_code)
				[self transmitCC:23 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kPortBtn_code)
				[self transmitCC:24 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kKnobAssignOneBtn_code)
				[self transmitCC:25 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
			else if(button_code == kKnobAssignTwoBtn_code)
				[self transmitCC:26 channel:buttonCh value:BUTTON_OFF_CC_VALUE];
		}
	}
	else if([event type] == PSPadKontrolEncoderTurnEventType)
	{
		uint8_t direction = *event.values;
		if(inNoteChangeMode)
		{
			if((direction == kEncoderDirectionLeft) && (activePatternSet.activePattern.note > 1))
				self.activePatternSet.activePattern.note -= 1;
			else if((direction == kEncoderDirectionRight) && (activePatternSet.activePattern.note < 127))
				self.activePatternSet.activePattern.note += 1;
			[self displayCurrentNoteOnLED];
		}
		else if(inChannelChangeMode)
		{
			if((direction == kEncoderDirectionLeft) && (activePatternSet.activePattern.channel > 1))
				self.activePatternSet.activePattern.channel -= 1;
			else if((direction == kEncoderDirectionRight) && (activePatternSet.activePattern.channel < 127))
				self.activePatternSet.activePattern.channel += 1;
			[self displayCurrentChannelOnLED];
		}
		else
		{
			if(direction == kEncoderDirectionLeft)
				[self transmitCC:32 channel:5 value:127];		
			else if(direction == kEncoderDirectionRight)
				[self transmitCC:33 channel:5 value:127];		
		}
	}
	else if([event type] == PSPadKontrolKnobTurnEventType)
	{
		uint8_t ccCode;
		if(event.affected_entity_code == kKnobOne_code)
			ccCode = 27;
		else if(event.affected_entity_code == kKnobTwo_code)
			ccCode = 28;
		[self transmitCC:ccCode channel:5 value:*event.values];
	}
	else if([event type] == PSPadKontrolXYPadPressEventType)
		[self transmitCC:29 channel:5 value:127];
	else if([event type] == PSPadKontrolXYPadReleaseEventType)
		[self transmitCC:29 channel:5 value:0];
	else if([event type] == PSPadKontrolXYPadMoveEventType)
	{
		[self transmitCC:30 channel:5 value:*event.values];
		[self transmitCC:31 channel:5 value:*(event.values+1)];
	}
}

- (void)displayCurrentNoteOnLED
{
	[[PSPadKontrol sharedPadKontrol] setLEDNumber:(NSInteger)activePatternSet.activePattern.note blink:NO];
}
- (void)displayCurrentChannelOnLED
{
	[[PSPadKontrol sharedPadKontrol] setLEDNumber:(NSInteger)activePatternSet.activePattern.channel blink:NO];
}

// Updates the lights on the controller
// For information on the multipleLight thing, read PadKontrolConstants
- (void)updateLights
{
	PSPattern *activePattern = [activePatternSet activePattern];
	uint8_t groupOne   = 0x00;
	uint8_t groupTwo   = 0x00;
	uint8_t groupThree = 0x00;
	uint8_t groupFour  = 0x00;
	uint8_t groupFive  = 0x00;
	
	if(self.activeView == PSSequencerSequencerView)
	{
		PSStep *currStep;
		// Light the pads corresponding to active steps
		for(int i = 0; i < 16; ++i)
		{
			currStep = [[activePattern steps] objectAtIndex:i];
			if(currStep.enabled)
			{
				if(i < 7)
					groupOne = groupOne | kMultipleLightGroup[i];
				else if(i < 14)
					groupTwo = groupTwo | kMultipleLightGroup[i - 7];
				else if(i < 16)
					groupThree = groupThree | kMultipleLightGroup[i - 14];
			}
		}
	}
	else if(self.activeView == PSSequencerPatternSelectView)
	{
		// Light the activator button
		groupThree |= kMultipleLightGroup[2];
		
		// Highlight the pad corresponding the active pattern
		NSUInteger selectedIndex = [activePatternSet.patterns indexOfObject:activePattern];
		if(selectedIndex < 7)
			groupOne |= kMultipleLightGroup[selectedIndex];
		else if(selectedIndex < 14)
			groupTwo |= kMultipleLightGroup[selectedIndex - 7];
		else if(selectedIndex < 16)
			groupThree |= kMultipleLightGroup[selectedIndex - 14];
	}
	else if(self.activeView == PSSequencerStepMuteView)
	{
		// Light the activator button
		groupFive |= kMultipleLightGroup[5];
		
		NSMutableIndexSet *mutedSteps = activePatternSet.mutedSteps;
		NSUInteger index = [mutedSteps firstIndex];
		while(index != NSNotFound)
		{
			if(index < 7)
				groupOne |= kMultipleLightGroup[index];
			else if(index < 14)
				groupTwo |= kMultipleLightGroup[index - 7];
			else if(index < 16)
				groupThree |= kMultipleLightGroup[index - 14];
			
			index = [mutedSteps indexGreaterThanIndex:index];
		}
	}
	else if(self.activeView == PSSequencerPatternSetSelectView)
	{
		groupThree |= kMultipleLightGroup[3];
		// Highlight the pad corresponding the active pattern set
		NSUInteger selectedIndex = [self.patternSets indexOfObject:activePatternSet];
		if(selectedIndex < 7)
			groupOne |= kMultipleLightGroup[selectedIndex];
		else if(selectedIndex < 14)
			groupTwo |= kMultipleLightGroup[selectedIndex - 7];
		else if(selectedIndex < 16)
			groupThree |= kMultipleLightGroup[selectedIndex - 14];
		
	}
	else if(self.activeView == PSSequencerPatternCopyView)
	{
		groupFive |= kMultipleLightGroup[4];
		
		groupOne = 0x7f;
		groupTwo = 0x7f;
		groupThree |= kMultipleLightGroup[0]| kMultipleLightGroup[1];
	}
	else if(self.activeView == PSSequencerPatternSetSequencerView)
	{
		NSUInteger stepsToLight = 16;
		if(self.shiftButtonHeld) // delete view
			stepsToLight = [self.patternSetSequencerSteps count];
		else if(self.patSetSeqViewPlaceMode)
			stepsToLight = [self.patternSetSequencerSteps count] + 1;
		for(int i = 0; i < stepsToLight; ++i)
		{
			if(i < 7)
				groupOne = groupOne | kMultipleLightGroup[i];
			else if(i < 14)
				groupTwo = groupTwo | kMultipleLightGroup[i - 7];
			else if(i < 16)
				groupThree = groupThree | kMultipleLightGroup[i - 14];
		}
	}
	
	// Make sure toggle buttons are correctly lit
	if(!self.velocityEnabled)
		groupFour |= kMultipleLightGroup[4];
	if(self.inPatternSetSequencingMode)
		groupFour |= kMultipleLightGroup[5];
	
	// Create the mask and turn on the lights
	uint8_t *mask;
	mask = [[PSPadKontrol sharedPadKontrol] buildMultipleLightControlMaskFromGroupOne:&groupOne
																																								two:&groupTwo
																																							three:&groupThree
																																							 four:&groupFour
																																							 five:&groupFive];
	[[PSPadKontrol sharedPadKontrol] controlMultipleLights:mask ledMask:NULL];
	free(mask);
	
	// If necessary, flash the currently playing pattern set in the pattern set sequencer
	if(self.activeView == PSSequencerPatternSetSequencerView && inPatternSetSequencingMode)
	{
		uint8_t lightCode = kPadOn_codes[currentPatSetSeqStep];
		uint8_t lightState = kPad_blink_code;
		[[PSPadKontrol sharedPadKontrol] controlLight:&lightCode state:&lightState];
	}
}
#pragma mark -
// MIDI interface
- (void)takeMIDIMessages:(NSArray *)messages
{
	// We don't really receive anything except SysEx's
}
- (void)transmitCC:(uint8_t)ccNumber channel:(uint8_t)channel value:(uint8_t)value
{
	uint8_t data[2] = { ccNumber, value };
	SMVoiceMessage *message = [SMVoiceMessage voiceMessageWithTimeStamp:SMGetCurrentHostTime()
																													 statusByte:SMVoiceMessageStatusControl
																																 data:data
																															 length:sizeof(uint8_t)*2];
	[message setChannel:channel];
	[virtualOutputStream takeMIDIMessages:[NSArray arrayWithObject:message]];
}
#pragma mark -
- (void)clockPulseHappened:(PSClock *)clock
{
	[self performStep];
}
- (void)clockDidStop:(PSClock *)clock
{
	[self resetSequencer];
}
- (void)clockDidStart:(PSClock *)clock
{
}

- (void)dealloc
{
	[midiMessagesAlive release];
	
	[super dealloc];
}
@end
