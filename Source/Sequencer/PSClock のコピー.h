//
//  PSClock.h
//  Meedee
//
//  Created by フィヨ on 10/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>

// App wide clock.
// This class is a singleton

@class SMVirtualInputStream;

@interface PSClock : NSObject <SMMessageDestination> {
	// MIDI clock syncing (clock is 24 times per beat)
	NSUInteger midiClockCount;
	uint64_t timeOfLastMidiClock;
	BOOL midiSyncEnabled;
	
	// The internal clock
	// Q. Note = bpm*4.
	// We tick 24 times per q. note
	void (^tickBlock)(void);
	dispatch_source_t tickTimer;
	uint64_t lastQuarterNote;
	uint64_t tickCount;
	double bpm;
	BOOL bpmChanged;
	
	BOOL running;
	
	// For MIDI clock syncing
	SMVirtualInputStream *virtualInputStream;
}
@property(readwrite, retain) SMVirtualInputStream *virtualInputStream;

+ (PSClock *)globalClock;

- (uint64_t)tickInterval;

- (void)start;
- (void)stop;
@end
