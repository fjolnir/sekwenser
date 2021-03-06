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
#import "SekwenserAppDelegate.h"

#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSECombinationOutputStream.h"

#import "PadKontrolConstants.h"
#import "PSPadKontrol.h"
#import "PSPadKontrolEvent.h"

#import <mach/mach_time.h>

#define BUTTON_ON_CC_VALUE  127
#define BUTTON_OFF_CC_VALUE 0

@interface PSSequencer () // Private
- (void)displayCurrentNoteOnLED;
- (void)displayCurrentChannelOnLED;
- (void)transmitCC:(uint8_t)ccNumber channel:(uint8_t)channel value:(uint8_t)value;
@end
#pragma mark -

@implementation PSSequencer
@synthesize patternSets=_patternSets, numberOfSteps=_numberOfSteps, activePatternSet=_activePatternSet, currentStep=_currentStep, inPatternSetSequencingMode=_inPatternSetSequencingMode, patternSetSequencerSteps=_patternSetSequencerSteps, currentPatSetSeqStep=_currentPatSetSeqStep, patSetSeqViewPlaceMode=_patSetSeqViewPlaceMode, patSetSeq_stepToPlace=_patSetSeq_stepToPlace, activeView=_activeView, isModal=_isModal, shiftButtonHeld=_shiftButtonHeld, velocityEnabled=_velocityEnabled, inNoteChangeMode=_inNoteChangeMode, inChannelChangeMode=_inChannelChangeMode, isActive=_isActive;

- (id)init {
	if(!(self = [super init]))
		 return nil;
	
	[self resetSequencer];
	
	_isActive = YES;
	_activeView = PSSequencerSequencerView;
	_velocityEnabled = NO;
	_isModal = NO;
	
	_midiMessagesAlive = [[NSMutableArray alloc] init];
	
	_patternSetSequencerSteps = [[NSMutableArray alloc] init];

	// Create the patterns
	_patternSets = [[NSMutableArray alloc] init];
	for(int i = 0; i < 16; ++i) {
		[_patternSets addObject:[PSPatternSet patternSetWithEmptyPatterns:16 activePattern:0]];
	}
	self.activePatternSet = [_patternSets objectAtIndex:0];
	
	// Subscribe to the clock
	[[[PSClock globalClock] listeners] addObject:self];

	// Initialize the lights on the controller
	[self updateLights];
	
	return self;
}
- (void)dealloc {
	[_midiMessagesAlive release];
  [_patternSets release];
  [_activePatternSet release];
  [_patternSetSequencerSteps release];
	
	[super dealloc];
}

- (void)resetSequencer {
	_currentStep = 0;
}

- (void)performStep {	
	if(!_isActive)
		return;
	NSMutableArray *midiMessages = [NSMutableArray array];
	
	PSPatternSet *patternSet = _activePatternSet;
	// If in pattern set sequencing mode we play the currently active pattern set
	if(_inPatternSetSequencingMode) {
		NSNumber *setIndex;
		if(_currentPatSetSeqStep < [_patternSetSequencerSteps count]) {
			setIndex = [_patternSetSequencerSteps objectAtIndex:_currentPatSetSeqStep];
			patternSet = [_patternSets objectAtIndex:[setIndex intValue]];
		}
		else
			return; // nothing to play
	}
	
	
	// Turn off all notes currently on
	for(SMVoiceMessage *aMsg in _midiMessagesAlive) {
		[aMsg setStatus:SMVoiceMessageStatusNoteOff];
		[aMsg setDataByte2:0x00];
		[midiMessages addObject:aMsg];
	}
	[_midiMessagesAlive removeAllObjects];
	
	Byte noteData[2] = {0x00, 0x00};
	for(PSPattern *pattern in patternSet.patterns) {
		// Send the note  for the active step
		PSStep *step = [pattern.steps objectAtIndex:_currentStep];
		if(![patternSet.mutedSteps containsIndex:_currentStep] && step.enabled) {	
			noteData[0] = pattern.note;
			noteData[1] = step.velocity;
			
			SMVoiceMessage *message = [SMVoiceMessage voiceMessageWithTimeStamp:SMGetCurrentHostTime()
																															 statusByte:SMVoiceMessageStatusNoteOn 
																																		 data:noteData 
																																	 length:2];
			[message setChannel:pattern.channel];
			[midiMessages addObject:message];
			[_midiMessagesAlive addObject:message];
		}
	}
	[SekwenserMIDIOutStream() takeMIDIMessages:midiMessages];

	// If we're in the sequencer view we flash the current step
	// Unless it's muted, in which case it'll be skipped over
	if(_activeView == PSSequencerSequencerView && [self isKey]) {
		uint8_t lightCode = kPadOn_codes[_currentStep];
		uint8_t lightState = kPad_shortOneshot_code+0x02; // add 2 to make the flash slightly longer
		[[PSPadKontrol sharedPadKontrol] controlLight:&lightCode state:&lightState];
	}
	else if(_activeView == PSSequencerPatternSetSequencerView && _inPatternSetSequencingMode) {
		// In pattern set sequencer view the blinking is handled, in updateLights
		// Reason being if we don't update/maintain the blink status after updating the lights, things'll look ugly
		[self updateLights];
	}
	
	// Increment the step
	if(++_currentStep > 15) {
		_currentStep = 0;
		if(++_currentPatSetSeqStep >= [_patternSetSequencerSteps count])
			_currentPatSetSeqStep = 0;
	}
}

- (void)selectView:(PSSequencerView)view {
	if(_activeView == PSSequencerSequencerView || view == PSSequencerSequencerView) {
		_activeView = view;
        [[PSPadKontrol sharedPadKontrol] setLEDString:"   " blink:NO];
		[self updateLights];
	}
}

#pragma mark -
- (void)didBecomeKey
{
    [[PSPadKontrol sharedPadKontrol] setLEDString:"SEQ" blink:NO];
}
- (void)padPressed:(PSPadKontrolEvent *)event {
    // If this is positive at the end of the block, the lights on the controller will be refreshed
    BOOL updateLights = YES;
	PSPattern *activePattern = [_activePatternSet activePattern];
    if(_activeView == PSSequencerSequencerView) {
        PSStep *step = [[activePattern steps] objectAtIndex:event.affectedPad];

        step.enabled = !step.enabled;
        if(_velocityEnabled)
            step.velocity = event.velocity;
        [[PSPadKontrol sharedPadKontrol] setLEDNumber:step.velocity blink:NO];
    }
    else if(_activeView == PSSequencerPatternSelectView) {
        _activePatternSet.activePattern = [_activePatternSet.patterns objectAtIndex:event.affectedPad];
    }
    else if(_activeView == PSSequencerStepMuteView) {
        if([_activePatternSet.mutedSteps containsIndex:event.affectedPad])
            [_activePatternSet.mutedSteps removeIndex:event.affectedPad];
        else
            [_activePatternSet.mutedSteps addIndex:event.affectedPad];

    }
    else if(_activeView == PSSequencerPatternSetSelectView) {
        self.activePatternSet = [_patternSets objectAtIndex:event.affectedPad];
    }
    else if(_activeView == PSSequencerPatternCopyView) {
        updateLights = NO;
        if(!_performingCopy)
        {
            uint8_t lightCode = kPadOn_codes[event.affectedPad];
            [[PSPadKontrol sharedPadKontrol] controlLight:&lightCode
                                                    state:(uint8_t *)&kPad_blink_code];
            _currentCopySource = event.affectedPad;
            _performingCopy = YES;
        }
        else {
            // Peform the actual copy
            PSPatternSet *setToCopy = [_patternSets objectAtIndex:_currentCopySource];
            PSPatternSet *destinationSet = [_patternSets objectAtIndex:event.affectedPad];
            [destinationSet copyPatternSet:setToCopy];
            // Update the lights
            uint8_t sourceLightCode = kPadOn_codes[_currentCopySource];
            uint8_t destLightCode   = kPadOn_codes[event.affectedPad];
            [[PSPadKontrol sharedPadKontrol] controlLight:&sourceLightCode
                                                    state:(uint8_t *)&kPad_lightOn_code];
            [[PSPadKontrol sharedPadKontrol] controlLight:&destLightCode
                                                    state:(uint8_t *)&kPad_shortOneshot_code];
            _performingCopy = NO;
        }
    }
    else if(_activeView == PSSequencerPatternSetSequencerView) {
        NSUInteger index = event.affectedPad;

        if(_shiftButtonHeld) {
            if(index < [_patternSetSequencerSteps count]) {
                if(index == [_patternSetSequencerSteps count])
                    _currentPatSetSeqStep = 0;
                [_patternSetSequencerSteps removeObjectAtIndex:index];
            }
            _patSetSeqViewPlaceMode = NO;
        }
        if(_patSetSeqViewPlaceMode) {
            if(index < [_patternSetSequencerSteps count])
                [_patternSetSequencerSteps replaceObjectAtIndex:index withObject:[NSNumber numberWithInt:_patSetSeq_stepToPlace]];
            else if(index == [_patternSetSequencerSteps count])
                [_patternSetSequencerSteps addObject:[NSNumber numberWithInt:_patSetSeq_stepToPlace]];
        }
        else
            _patSetSeq_stepToPlace = index;
        _patSetSeqViewPlaceMode = !_patSetSeqViewPlaceMode;
        
        updateLights = YES;
    }
    
    if(updateLights) [self updateLights];
}
- (void)button:(uint8_t)button_code wasPressed:(PSPadKontrolEvent *)event {
//    if(button_code == kSettingBtn_code) {
//        [[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];
//        _shiftButtonHeld = YES;
//        [self updateLights];
//    }

    if(!_isModal && !_shiftButtonHeld) {
        // Light the button
        [[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];

        // Buttons in order of appearance on controller
        if(button_code == kSceneBtn_code) {
            [self selectView:PSSequencerPatternSelectView];
            _isModal = YES;
        }
        else if(button_code == kMessageBtn_code) {
            [self selectView:PSSequencerPatternSetSelectView];
            _isModal = YES;
        }
        else if(button_code == kHoldBtn_code) {
            [self selectView:PSSequencerPatternSetSequencerView];
            _isModal = YES;
        }
        else if(button_code == kFlamBtn_code) {
            [self selectView:PSSequencerStepMuteView];
            _isModal = YES;
        }
        else if(button_code == kRollBtn_code) {
            [self selectView:PSSequencerPatternCopyView];
            _isModal = YES;
        }
    }
    // Shift mode (less often used functions)
    // In shift mode we only light the button if it has a function
    else if(_shiftButtonHeld) {
        if(button_code == kNoteCCBtn_code) {
            _inNoteChangeMode = YES;
            [self displayCurrentNoteOnLED];
            
            [[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];
        }
        else if(button_code == kMidiCHBtn_code) {
            _inChannelChangeMode = YES;
            [self displayCurrentChannelOnLED];
            
            [[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOn_code];
        }
    }
}
- (void)button:(uint8_t)button_code wasReleased:(PSPadKontrolEvent *)event {
    // Turn the button back off
    [[PSPadKontrol sharedPadKontrol] controlLight:&button_code state:(uint8_t *)&kPad_lightOff_code];

    if(button_code == kSettingBtn_code) {
        _shiftButtonHeld = NO;
        [self updateLights];
    }
    // Return to sequencer mode
    else if((button_code == kSceneBtn_code  && _activeView == PSSequencerPatternSelectView)
            ||  (button_code == kFlamBtn_code    && _activeView == PSSequencerStepMuteView)
            ||  (button_code == kMessageBtn_code && _activeView == PSSequencerPatternSetSelectView)
            ||  (button_code == kRollBtn_code    && _activeView == PSSequencerPatternCopyView)
            ||  (button_code == kHoldBtn_code    && _activeView == PSSequencerPatternSetSequencerView)) {
        [self selectView:PSSequencerSequencerView];
        _isModal = NO;
        _performingCopy = NO;
    }
    else if(button_code == kNoteCCBtn_code) {
        _inNoteChangeMode = NO;
        [[PSPadKontrol sharedPadKontrol] clearLED];
    }
    else if(button_code == kMidiCHBtn_code) {
        _inChannelChangeMode = NO;
        [[PSPadKontrol sharedPadKontrol] clearLED];
    }
    else if(button_code == kFixedVelBtn_code) {
        _velocityEnabled = !_velocityEnabled;
        [self updateLights];
    }
    else if(button_code == kProgChangeBtn_code) {
        // Toggle pattern sequencing mode
        _inPatternSetSequencingMode = !_inPatternSetSequencingMode;
        _currentPatSetSeqStep = 0;
        [self updateLights];
    }
}

- (void)encoderTurned:(PSPadKontrolEvent *)event direction:(uint8_t)direction {
    if(_inNoteChangeMode) {
        if((direction == kEncoderDirectionLeft) && (_activePatternSet.activePattern.note > 1))
            _activePatternSet.activePattern.note -= 1;
        else if((direction == kEncoderDirectionRight) && (_activePatternSet.activePattern.note < 127))
            _activePatternSet.activePattern.note += 1;
        [self displayCurrentNoteOnLED];
    }
    else if(_inChannelChangeMode) {
        if((direction == kEncoderDirectionLeft) && (_activePatternSet.activePattern.channel > 1))
            _activePatternSet.activePattern.channel -= 1;
        else if((direction == kEncoderDirectionRight) && (_activePatternSet.activePattern.channel < 127))
            _activePatternSet.activePattern.channel += 1;
        [self displayCurrentChannelOnLED];
    }
    else {
        if(direction == kEncoderDirectionLeft)
            TransmitCC(32, 5, 127);
        else if(direction == kEncoderDirectionRight)
            TransmitCC(33, 5, 127);		
    }
}

- (void)padKontrolReady {
    [self selectView:PSSequencerSequencerView];
    _isModal = NO;
    [self updateLights];
}

- (void)displayCurrentNoteOnLED {
	[[PSPadKontrol sharedPadKontrol] setLEDNumber:(NSInteger)_activePatternSet.activePattern.note blink:NO];
}
- (void)displayCurrentChannelOnLED {
	[[PSPadKontrol sharedPadKontrol] setLEDNumber:(NSInteger)_activePatternSet.activePattern.channel blink:NO];
}

// Updates the lights on the controller
// For information on the multipleLight thing, read PadKontrolConstants
- (void)updateLights {
	PSPattern *activePattern = [_activePatternSet activePattern];
	uint8_t groupOne   = 0x00;
	uint8_t groupTwo   = 0x00;
	uint8_t groupThree = 0x00;
	uint8_t groupFour  = 0x00;
	uint8_t groupFive  = 0x00;
	
	if(_activeView == PSSequencerSequencerView) {
		PSStep *currStep;
		// Light the pads corresponding to active steps
		for(int i = 0; i < 16; ++i) {
			currStep = [[activePattern steps] objectAtIndex:i];
			if(currStep.enabled) {
				if(i < 7)
					groupOne = groupOne | kMultipleLightGroup[i];
				else if(i < 14)
					groupTwo = groupTwo | kMultipleLightGroup[i - 7];
				else if(i < 16)
					groupThree = groupThree | kMultipleLightGroup[i - 14];
			}
		}
	}
	else if(_activeView == PSSequencerPatternSelectView) {
        [[PSPadKontrol sharedPadKontrol] setLEDString:"INS" blink:YES];
		// Light the activator button
		groupThree |= kMultipleLightGroup[2];
		
		// Highlight the pad corresponding the active pattern
		NSUInteger selectedIndex = [_activePatternSet.patterns indexOfObject:activePattern];
		if(selectedIndex < 7)
			groupOne |= kMultipleLightGroup[selectedIndex];
		else if(selectedIndex < 14)
			groupTwo |= kMultipleLightGroup[selectedIndex - 7];
		else if(selectedIndex < 16)
			groupThree |= kMultipleLightGroup[selectedIndex - 14];
	}
	else if(_activeView == PSSequencerStepMuteView) {
        [[PSPadKontrol sharedPadKontrol] setLEDString:"TGL" blink:NO];
		// Light the activator button
		groupFive |= kMultipleLightGroup[5];
		
		NSMutableIndexSet *mutedSteps = _activePatternSet.mutedSteps;
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
	else if(_activeView == PSSequencerPatternSetSelectView) {
        [[PSPadKontrol sharedPadKontrol] setLEDString:"BNK" blink:YES];
		groupThree |= kMultipleLightGroup[3];
		// Highlight the pad corresponding the active pattern set
		NSUInteger selectedIndex = [_patternSets indexOfObject:_activePatternSet];
		if(selectedIndex < 7)
			groupOne |= kMultipleLightGroup[selectedIndex];
		else if(selectedIndex < 14)
			groupTwo |= kMultipleLightGroup[selectedIndex - 7];
		else if(selectedIndex < 16)
			groupThree |= kMultipleLightGroup[selectedIndex - 14];
		
	}
	else if(_activeView == PSSequencerPatternCopyView) {
        [[PSPadKontrol sharedPadKontrol] setLEDString:"CPY" blink:YES];
		groupFive |= kMultipleLightGroup[4];
		
		groupOne = 0x7f;
		groupTwo = 0x7f;
		groupThree |= kMultipleLightGroup[0]| kMultipleLightGroup[1];
	}
	else if(_activeView == PSSequencerPatternSetSequencerView) {
        [[PSPadKontrol sharedPadKontrol] setLEDString:"PSE" blink:YES];
		NSUInteger stepsToLight = 16;
		if(_shiftButtonHeld) // delete view
			stepsToLight = [_patternSetSequencerSteps count];
		else if(_patSetSeqViewPlaceMode)
			stepsToLight = [_patternSetSequencerSteps count] + 1;
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
	if(!_velocityEnabled)
		groupFour |= kMultipleLightGroup[4];
	if(_inPatternSetSequencingMode)
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
	if(_activeView == PSSequencerPatternSetSequencerView && _inPatternSetSequencingMode) {
		uint8_t lightCode = kPadOn_codes[_currentPatSetSeqStep];
		uint8_t lightState = kPad_blink_code;
		[[PSPadKontrol sharedPadKontrol] controlLight:&lightCode state:&lightState];
	}
}
#pragma mark -
// MIDI interface
- (void)takeMIDIMessages:(NSArray *)messages {
	// We don't really receive anything except SysEx's
}

#pragma mark -
- (void)clockPulseHappened:(PSClock *)clock {
	[self performStep];
}
- (void)clockDidStop:(PSClock *)clock {
	[self resetSequencer];
}
- (void)clockDidStart:(PSClock *)clock {
}
@end
