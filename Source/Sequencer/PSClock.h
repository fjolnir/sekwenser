////////////////////////////////////////////////////////////////////////////////////////////
//
//  PSClock
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
