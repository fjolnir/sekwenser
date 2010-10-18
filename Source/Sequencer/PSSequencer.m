//
//  PSSequencer.m
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

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

static PSSequencer *sharedSequencer = nil;

@interface PSSequencer () // Private
- (void)displayCurrentNoteOnLED;
- (void)transmitCC:(uint8_t)ccNumber channel:(uint8_t)channel value:(uint8_t)value;
@end
#pragma mark -

@implementation PSSequencer
@synthesize patternSets, numberOfSteps, activePatternSet, virtualOutputStream, currentStep;

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
	
	activeView = PSSequencerSequencerView;
	velocityEnabled = NO;
	isModal = NO;

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

	[self updateLights];
	
	return self;
}

- (void)resetSequencer
{
	isActive = NO;
	self.currentStep = 0;
}

- (void)performStep
{	
	NSMutableArray *midiMessages = [NSMutableArray array];
	for(PSPattern *pattern in activePatternSet.patterns)
	{
		// Turn off the note for the last step
		for(PSStep *step in pattern.steps)
		{
			if(!step.noteOn)
				continue;
			// Else we send a noteoff
			Byte noteData[2] = {pattern.note, 0x00};
			Byte statusByte = SMVoiceMessageStatusNoteOff;
			SMVoiceMessage *message = [SMVoiceMessage voiceMessageWithTimeStamp:SMGetCurrentHostTime()
																															 statusByte:statusByte 
																																		 data:noteData 
																																	 length:2];
			[message setChannel:1];
			[midiMessages addObject:message];
			step.noteOn = NO;
		}
		// Send the note  for the active step
		PSStep *step = [pattern.steps objectAtIndex:currentStep];
		if(![activePatternSet.mutedSteps containsIndex:currentStep] && step.enabled)
		{
			//if(velocityEnabled) after thinking a bit I think it's better to just make the
			// fixed velocity switch affect the velocity at the pad hit, that way it's easy to
			// make pattern with most pads at full velocity, and then add inn some softer ones
			Byte velocity = step.velocity;
			Byte noteData[2] = {pattern.note, velocity};
			Byte statusByte = SMVoiceMessageStatusNoteOn;
			//if(clockCount%12 == 0)
			//	statusByte = SMVoiceMessageStatusNoteOff;
			
			SMVoiceMessage *message = [SMVoiceMessage voiceMessageWithTimeStamp:SMGetCurrentHostTime()
																															 statusByte:statusByte 
																																		 data:noteData 
																																	 length:2];
			[message setChannel:1];
			[midiMessages addObject:message];
			step.noteOn = YES;
		}
	}
	[virtualOutputStream takeMIDIMessages:midiMessages];

	// If we're in the sequencer view we flash the current step
	// Unless it's muted, in which case it'll be skipped over
	if(activeView == PSSequencerSequencerView)
	{
		uint8_t lightCode = kPadOn_codes[currentStep];
		uint8_t lightState = kPad_shortOneshot_code+0x02;
		[[PSPadKontrol sharedPadKontrol] controlLight:&lightCode state:&lightState];
	}
	
	// Increment the step
	if(++currentStep > 15)
		currentStep = 0;
}

- (void)selectView:(PSSequencerView)view
{
	if(activeView == PSSequencerSequencerView || view == PSSequencerSequencerView)
	{
		activeView = view;
		[self updateLights];
	}
}

#pragma mark -
// PadKontrol communication
- (void)padKontrolEventReceived:(PSPadKontrolEvent *)event fromPadKontrol:(PSPadKontrol *)padKontrol
{
	//NSLog(@"Received event from PadKontrol: %@", event);
	BOOL updateLights = YES;
	PSPattern *activePattern = [activePatternSet activePattern];
	if([event type] == PSPadKontrolEnteredNativeMode)
	{
		[self selectView:PSSequencerSequencerView];
		isModal = NO;
		[self updateLights];
	}
	else if([event type] == PSPadKontrolPadPressEventType)
	{
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
				NSLog(@"Flash it");
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
		if(updateLights)
			[self updateLights];
	}
	else if([event type] == PSPadKontrolButtonPressEventType)
	{
		uint8_t button_code = event.affected_entity_code;
		// Light the button
		if(!isModal)
		{
			[[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];
			if(button_code == kSceneBtn_code)
			{
				[self selectView:PSSequencerPatternSelectView];
				isModal = YES;
			}
			else if(button_code == kHoldBtn_code)
			{
				[self selectView:PSSequencerStepMuteView];
				isModal = YES;
			}
			else if(button_code == kMessageBtn_code)
			{
				[self selectView:PSSequencerPatternSetSelectView];
				isModal = YES;
			}
			else if(button_code == kRollBtn_code)
			{
				[self selectView:PSSequencerPatternCopyView];
				isModal = YES;
			}
			else if(button_code == kProgChangeBtn_code)
			{
				inNoteChangeMode = YES;
				[self displayCurrentNoteOnLED];
			}
		}
		// Buttons not used by the sequencer transmit MIDI CC and don't care about modality/other buttons
		uint8_t buttonCh = 5;
		if(button_code == kXBtn_code)
			[self transmitCC:16 channel:buttonCh value:127];
		if(button_code == kYBtn_code)
			[self transmitCC:17 channel:buttonCh value:127];
		if(button_code == kPedalBtn_code)
			[self transmitCC:18 channel:buttonCh value:127];
		if(button_code == kNoteCCBtn_code)
			[self transmitCC:19 channel:buttonCh value:127];
		if(button_code == kMidiCHBtn_code)
			[self transmitCC:20 channel:buttonCh value:127];
		if(button_code == kSWTypeBtn_code)
			[self transmitCC:21 channel:buttonCh value:127];
		if(button_code == kRelValBtn_code)
			[self transmitCC:22 channel:buttonCh value:127];
		if(button_code == kVelocityBtn_code)
			[self transmitCC:23 channel:buttonCh value:127];
		if(button_code == kPortBtn_code)
			[self transmitCC:24 channel:buttonCh value:127];
		if(button_code == kKnobAssignOneBtn_code)
			[self transmitCC:25 channel:buttonCh value:127];
		if(button_code == kKnobAssignTwoBtn_code)
			[self transmitCC:26 channel:buttonCh value:127];
	}
	else if([event type] == PSPadKontrolButtonReleaseEventType)
	{
		uint8_t button_code = event.affected_entity_code;
		// Turn the button back off
		[[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOff_code];
		// Return to sequencer mode
		if((button_code == kSceneBtn_code      && activeView == PSSequencerPatternSelectView)
			 || (button_code == kHoldBtn_code    && activeView == PSSequencerStepMuteView)
			 || (button_code == kMessageBtn_code && activeView == PSSequencerPatternSetSelectView)
			 || (button_code == kRollBtn_code    && activeView == PSSequencerPatternCopyView))
		{
			[self selectView:PSSequencerSequencerView];
			isModal = NO;
			performingCopy = NO;
		}
		else if(button_code == kFixedVelBtn_code)
		{
			NSLog(@"toggling velocity");
			velocityEnabled = !velocityEnabled;
			[self updateLights];
		}
		else if(button_code == kProgChangeBtn_code)
		{
			inNoteChangeMode = NO;
			[[PSPadKontrol sharedPadKontrol] clearLED];
		}
		
		// Buttons not used by the sequencer transmit MIDI CC and don't care about modality/other buttons
		uint8_t buttonCh = 5;
		if(button_code == kXBtn_code)
			[self transmitCC:16 channel:buttonCh value:0];
		if(button_code == kYBtn_code)
			[self transmitCC:17 channel:buttonCh value:0];
		if(button_code == kPedalBtn_code)
			[self transmitCC:18 channel:buttonCh value:0];
		if(button_code == kNoteCCBtn_code)
			[self transmitCC:19 channel:buttonCh value:0];
		if(button_code == kMidiCHBtn_code)
			[self transmitCC:20 channel:buttonCh value:0];
		if(button_code == kSWTypeBtn_code)
			[self transmitCC:21 channel:buttonCh value:0];
		if(button_code == kRelValBtn_code)
			[self transmitCC:22 channel:buttonCh value:0];
		if(button_code == kVelocityBtn_code)
			[self transmitCC:23 channel:buttonCh value:0];
		if(button_code == kPortBtn_code)
			[self transmitCC:24 channel:buttonCh value:0];
		if(button_code == kKnobAssignOneBtn_code)
			[self transmitCC:25 channel:buttonCh value:0];
		if(button_code == kKnobAssignTwoBtn_code)
			[self transmitCC:26 channel:buttonCh value:0];
	}
	else if([event type] == PSPadKontrolEncoderTurnEventType)
	{
		uint8_t direction = *event.values;
		if(inNoteChangeMode)
		{
			if((direction == kEncoderDirectionLeft) && (activePatternSet.activePattern.note > 1))
				activePatternSet.activePattern.note -= 1;
			else if((direction == kEncoderDirectionRight) && (activePatternSet.activePattern.note < 127))
				activePatternSet.activePattern.note += 1;
			[self displayCurrentNoteOnLED];
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
		if(event.affected_entity_code == kKnobTwo_code)
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
	
	if(activeView == PSSequencerSequencerView)
	{
		PSStep *currStep;
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
	else if(activeView == PSSequencerPatternSelectView)
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
	else if(activeView == PSSequencerStepMuteView)
	{
		// Light the activator button
		groupFive |= kMultipleLightGroup[6];
		
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
	else if(activeView == PSSequencerPatternSetSelectView)
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
	else if(activeView == PSSequencerPatternCopyView)
	{
		groupFive |= kMultipleLightGroup[4];
		
		groupOne = 0x7f;
		groupTwo = 0x7f;
		groupThree |= kMultipleLightGroup[0]| kMultipleLightGroup[1];
	}
	
	// Make sure toggle buttons are correctly lit
	if(!velocityEnabled)
		groupFour |= kMultipleLightGroup[4];
	//if(inNoteChangeMode)
	//	groupFour |= kMultipleLightGroup[5];
	
	// Create the mask and turn on the lights
	uint8_t *mask;
	mask = [[PSPadKontrol sharedPadKontrol] buildMultipleLightControlMaskFromGroupOne:&groupOne
																																								two:&groupTwo
																																							three:&groupThree
																																							 four:&groupFour
																																							 five:&groupFive];
	[[PSPadKontrol sharedPadKontrol] controlMultipleLights:mask ledMask:NULL];
	free(mask);
}
#pragma mark -
// MIDI interface
- (void)takeMIDIMessages:(NSArray *)messages
{
	// We don't really receive anything
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
	[super dealloc];
}
@end
