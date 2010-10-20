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


#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>
#import "PSClockListener.h"
#import "PSPadKontrolEventListener.h"

@class SSECombinationOutputStream;
@class SMPortInputStream;
@class PSPatternSet;
@class SMVirtualInputStream;
@class SMVirtualOutputStream;

typedef enum
{
	PSSequencerSequencerView = 1,
	PSSequencerPatternSetSelectView = 2,
	PSSequencerPatternSelectView = 3,
	PSSequencerStepMuteView = 4,
	PSSequencerPatternCopyView = 5,
	PSSequencerPatternSetSequencerView = 6
} PSSequencerView;

@interface PSSequencer : NSObject <SMMessageDestination, PSClockListener, PSPadKontrolEventListener> {	
	// The number of steps is not meant to be changed, I'm only keeping things dynamic so that if
	// anyone wants to implement support for a different controller than the PadKONTROL
	// it will be less of a hassle
	NSUInteger numberOfSteps; // Default 16
	NSUInteger currentStep;   // Default 0
	
	PSSequencerView activeView;
	BOOL isModal;
	
	BOOL isActive; // Are we stepping?
	
	BOOL velocityEnabled; // Do we use the velocity of the strike used to enable a pad?
	
	NSMutableArray *patternSets;
	PSPatternSet *activePatternSet;
		
	// MIDI interface
	SMVirtualOutputStream *virtualOutputStream;
	
	// For copying pattern sets
	BOOL performingCopy;
	NSUInteger currentCopySource;
	
	// For changing notes of patterns
	BOOL inNoteChangeMode;
	// For changing channels of patterns
	BOOL inChannelChangeMode;
	
	// Indicates wether the shift button is held (setting button)
	BOOL shiftButtonHeld;
	
	// The pattern sequencer 
	// A sequencer on top of the sequencer really.
	// Allows you to specify patterns to play in an order. This is done independently of what pattern you are editing
	// Using this you could also create a 1 step pattern sequencer,
	// and then create a new pattern while the pattern sequencer plays pattern
	BOOL inPatternSetSequencingMode;
	NSMutableArray *patternSetSequencerSteps;
	NSUInteger currentPatSetSeqStep;
	
	// The pattern sequencer editor view state
	
	// If NO the user is meant to select a step to add to the sequencer
	// If YES he's meant to select a destination position in the sequence
	BOOL patSetSeqViewPlaceMode;
	NSUInteger patSetSeq_stepToPlace;
}
@property(readwrite, assign) BOOL isActive;

@property(readwrite, retain) NSMutableArray *patternSets;
@property(readwrite, retain) PSPatternSet *activePatternSet;

@property(readwrite, assign) NSUInteger numberOfSteps;
@property(readwrite, assign) NSUInteger currentStep;

@property(readwrite, assign) PSSequencerView activeView;
@property(readwrite, assign) BOOL isModal;

@property(readwrite, assign) BOOL inNoteChangeMode;
@property(readwrite, assign) BOOL inChannelChangeMode;

@property(readwrite, retain) SMVirtualOutputStream *virtualOutputStream;

@property(readwrite, assign) BOOL shiftButtonHeld;
@property(readwrite, assign) BOOL velocityEnabled;

@property(readwrite, assign) BOOL inPatternSetSequencingMode;
@property(readwrite, retain) NSMutableArray *patternSetSequencerSteps;
@property(readwrite, assign) NSUInteger currentPatSetSeqStep;
@property(readwrite, assign) BOOL patSetSeqViewPlaceMode;
@property(readwrite, assign) NSUInteger patSetSeq_stepToPlace;

+ (PSSequencer *)sharedSequencer;

- (void)updateLights;

- (void)performStep;
- (void)resetSequencer; // You most likely shouldn't be calling this one much
@end
