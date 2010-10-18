//
//  PSClock.m
//  Meedee
//
//  Created by フィヨ on 10/10/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PSClock.h"
#import <SnoizeMIDI/SnoizeMIDI.h>
#import <mach/mach_time.h>

PSClock *sharedInstance;

@implementation PSClock
@synthesize virtualInputStream;

+ (PSClock *)globalClock
{
	@synchronized(self)
	{
		if(!sharedInstance)
			sharedInstance = [[self alloc] init];
	}
	return sharedInstance;
}

- (id)init
{
	if(!(self = [super init]))
		return nil;
	
	bpm = 130.0;
	bpmChanged = NO;
	tickCount = 0;
	
	//
	// Create a virtual input port (for receiving clock from software)
	virtualInputStream = [[SMVirtualInputStream alloc] init];
	[self.virtualInputStream setMessageDestination:self];
	[self.virtualInputStream setSelectedInputSources:[NSSet setWithArray:[virtualInputStream inputSources]]];
	
	timeOfLastMidiClock = 0;
	midiClockCount = 0;
	
	tickBlock = ^{
		//NSLog(@"%d", tickCount);
		// If the bpm has Changed we need to readjust the interval
		if(bpmChanged)
		{
			NSLog(@"BPM changed => recalculating tick interval");
			dispatch_time_t now = dispatch_walltime(DISPATCH_TIME_NOW, 0);
			dispatch_source_set_timer(tickTimer, now, [self tickInterval], 5000ull);
		}
		// Every 6th tick there's a clock event
		if(tickCount % 6 == 0)
		{
			
		}
		// Every 24th tick we hit a quarter note/beat
		if(tickCount % 24 == 0)
		{
			mach_timebase_info_data_t timeInfo;
			mach_timebase_info(&timeInfo);
			
		  uint64_t now = mach_absolute_time();
			uint64_t difference = now - lastQuarterNote;
			// Make sure we're working with nanoseconds
			difference *= timeInfo.numer;
			difference /= timeInfo.denom;
			
			double fDifference = difference;
			NSLog(@"diff %llu", difference);
			double realBPM = (60000000000/(double)fDifference);
			printf("BPM: %f (calculated: %f)\n", bpm, realBPM);
			lastQuarterNote = mach_absolute_time();
		}
		++tickCount;
	};
	
	dispatch_queue_t q_default;
	q_default = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
	tickTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, q_default); //run event handler on the default global queue
	dispatch_source_set_event_handler(tickTimer, tickBlock);

	return self;
}

// Returns the appropriate tick interval in nanoseconds
- (uint64_t)tickInterval
{
	// Determine the tick interval in microseconds
	uint64_t microtempo = USEC_PER_SEC;
	microtempo *= 60;
	microtempo /= bpm;
	uint64_t tickInterval = microtempo/24;
	NSLog(@"microtempo %llu tick %llu", microtempo, tickInterval);
	
	return tickInterval * NSEC_PER_USEC;
}
- (void)start
{
	running = YES;
	
	dispatch_time_t now = dispatch_walltime(DISPATCH_TIME_NOW, 0);
	dispatch_source_set_timer(tickTimer, now, [self tickInterval], 0ull);
	dispatch_resume(tickTimer);
}
- (void)stop
{
	running = NO;
	dispatch_suspend(tickTimer);
}
#pragma mark -
// MIDI syncing
- (void)takeMIDIMessages:(NSArray *)messages
{
	for(SMMessage *message in messages)
	{
		//NSLog(@"Received MIDI %@ from %@", message, [message originatingEndpointForDisplay]);
		//NSLog(@"%@",message);
		if([message isMemberOfClass:[SMSystemRealTimeMessage class]])
			//[message matchesMessageTypeMask:SMMessageTypeClock|SMMessageTypeStart|SMMessageTypeStop|SMMessageTypeContinue])
		{
			SMSystemRealTimeMessage *timeMsg = (SMSystemRealTimeMessage *)message;
			//NSLog(@"Received %@ - %@ - status %x", [timeMsg typeForDisplay], [timeMsg timeStampForDisplay], [timeMsg statusByte]);
			if([timeMsg type] == SMSystemRealTimeMessageTypeStart)
			{
				NSLog(@"Received Start Message. Starting sequencer");
			}
			else if([timeMsg type] == SMSystemRealTimeMessageTypeStop)
			{
				NSLog(@"Received Stop Message. Resetting sequencer");
			}
			else if([timeMsg type] == SMSystemRealTimeMessageTypeClock)
			{
				if(midiClockCount !=95)
				{
					if((midiClockCount % 23) == 0) // Seems ableton sends 23 clocks per beat(?)
					{
						NSLog(@"bpm %f %d", bpm, lround(bpm));
						//NSLog(@"------BEAT");
						//NSTimeInterval timeSinceLastBeat = [self.lastBeat timeIntervalSinceNow]*-1.0;
						//NSLog(@"Time since last beat: %f", timeSinceLastBeat);
						//double bpm = 30.0 / timeSinceLastBeat;
						//printf("%f\n", bpm);
						//[self performStep];
					}
					++midiClockCount;
				}
				else {
					uint64_t currentTime = mach_absolute_time();
					uint64_t difference = currentTime - timeOfLastMidiClock;
					float elapsed = difference;
					bpm = (60000000000/elapsed)*4;
					midiClockCount = 0;
					timeOfLastMidiClock = mach_absolute_time();
				}
			}
		}
	}
}



#pragma mark -
// Singleton stuff
+ (id)allocWithZone:(NSZone *)zone
{
	@synchronized(self) {
		if (sharedInstance == nil) {
			sharedInstance = [super allocWithZone:zone];
			return sharedInstance;  // assignment and return on first allocation
		}
	}
	return nil; //on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone
{
	return self;
}

- (id)retain
{
	return self;
}

- (unsigned)retainCount
{
	return UINT_MAX;  // Cannot be released
}

- (void)release
{
	// Do nothing
}

- (id)autorelease
{
	return self;
}
@end
