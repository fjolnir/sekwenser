//
//  PSSequencer.h
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//


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
	PSSequencerPatternCopyView = 5
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
}
@property(readwrite, retain) NSMutableArray *patternSets;
@property(readwrite, retain) PSPatternSet *activePatternSet;

@property(readwrite, assign) NSUInteger numberOfSteps;
@property(readwrite, assign) NSUInteger currentStep;

@property(readwrite, retain) SMVirtualOutputStream *virtualOutputStream;

+ (PSSequencer *)sharedSequencer;

- (void)updateLights;

- (void)performStep;
- (void)resetSequencer; // You most likely shouldn't be calling this one much
@end
