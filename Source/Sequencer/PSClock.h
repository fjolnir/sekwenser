//
//  PSClock.h
//  sekwenser
//
//  Created by フィヨ on 10/10/10.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>
#import <AudioToolbox/CoreAudioClock.h>
#import <CoreMIDI/CoreMIDI.h>
#import "PSClockListener.h"

// Cocoa frontend for the Core Audio clock

@class SMVirtualInputStream;

@interface PSClock : NSObject {
	// CoreAudio clock
	CAClockRef caClock;
	
	MIDIClientRef clientRef;
	MIDIPortRef inputPortRef;
	MIDIEndpointRef srcPointRef;
	CAClockSeconds keepSeconds;
	
	// the internal bpm, only accurate if internal syncing is used
	// Otherwise it has to be multiplied by the playrate (handled by -currentBPM)
	CAClockTempo internalBPM;
	
	// The interval between clock pulses. Specified in beats (Default: 0.25 => 4 times per beat)
	CAClockBeats pulseInterval;
	
	void (^beatCheckBlock)(void);
		
	BOOL running;
	
	NSMutableArray *listeners;
}
@property(readwrite, assign) CAClockBeats pulseInterval;
@property(readwrite, retain) NSMutableArray *listeners;
@property(readonly) CAClockRef caClock;

+ (PSClock *)globalClock;

- (void)start;
- (void)stop;
- (void)arm;
- (void)disarm;

// Sets the internal bpm, will be overridden by midi sync
- (void)setInternalBPM:(CAClockTempo)inTempo;
// In most cases you'll want to call -currentBPM instead, as that will give you the actual playback BPM
- (CAClockTempo)internalBPM;

// See CoreAudioClock.h for syncmodes
- (void)setSyncMode:(CAClockSyncMode)syncMode;
- (void)setMIDISyncSource:(NSString *)name;

// Returns the current beat number. (CAClockBeats = Float64)
- (CAClockBeats)currentBeat;
// Returns the current synced BPM
- (CAClockTempo)currentBPM;
@end
