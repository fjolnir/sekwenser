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


#import "PSClock.h"
#import <SnoizeMIDI/SnoizeMIDI.h>
#import <mach/mach_time.h>

PSClock *sharedInstance;

@interface PSClock ()
- (void)clockListener:(CAClockMessage)message parameter:(const void *)param;
- (void)sendSelectorToListeners:(SEL)selector;
@end

static void MIDIInputProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon);
static void clockListener(void *userData, CAClockMessage message, const void *param);
@implementation PSClock
@synthesize pulseInterval, listeners, caClock;

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
		
	OSErr err = 0;
	
	NSString *clientName = @"sekwenser";
	err = MIDIClientCreate((CFStringRef)clientName, NULL, NULL, &clientRef);
	if (err != noErr) {
		NSLog(@"MIDIClientCreate err = %d", err);
	}
	
	[self setMIDISyncSource:nil];	
	
	//
	// Set up the CoreAudio Clock
	CAClockNew(0, &caClock);
	
	CAClockAddListener(caClock, clockListener, self);
		
	CAClockTimebase timebase = kCAClockTimebase_HostTime;
	err = CAClockSetProperty(caClock, kCAClockProperty_InternalTimebase, sizeof(CAClockTimebase), &timebase);
	if(err)
		NSLog(@"Error setting clock timebase");
	
	// Enable MIDI syncing by default
	[self setSyncMode:kCAClockSyncMode_MIDIClockTransport];

	
	UInt32 SMPTEType = kSMPTETimeType24;
	err = CAClockSetProperty(caClock, kCAClockProperty_SMPTEFormat, sizeof(CAClockSMPTEFormat), &SMPTEType);
	if(err)
		NSLog(@"Error setting clock SMPTE type");
	
	// Create a midi port
	NSString *inputPortName = @"sekwenser in";
	err = MIDIInputPortCreate(clientRef, (CFStringRef)inputPortName, 
														MIDIInputProc, self, &inputPortRef);
	if (err != noErr) {
		NSLog(@"MIDIInputPortCreate err = %d", err);
	}
	
	// Connect the endpoint to our port
	err = MIDIPortConnectSource(inputPortRef, srcPointRef, NULL);
	if (err)
		NSLog(@"MIDIPortConnectSource err = %d", err);
		
	// Not running at the start now are we?
	running = NO;
	
	self.pulseInterval = 0.25; // default to 1/4
	self.listeners = [NSMutableArray array];
	
	
	return self;
}


#pragma mark -
// Status change methods
- (void)start
{
	// We can't call CAClockStart if the clock is already running
	// That causes an infinite recursion (on this method) so we make sure not to.
	// When the clock is started from a midi source the running variable should be assigned to YES
	// before -(void)start is executed
	if(!running)
		CAClockStart(caClock);
	running = YES;
	
	// Polling like this is dirty but I see no other way of knowing when a beat hits.
	// There's no notification mechanism in the CAClock api
	// Someone please rewrite this to not do any polling
	beatCheckBlock = ^{
		// Get the reference beat time used to find when the next beat hits
		CAClockTime originalBeatTime;
		CAClockGetCurrentTime(caClock, kCAClockTimeFormat_Beats, &originalBeatTime);
		 // Make sure we're incrementing a whole beat
		originalBeatTime.time.beats = roundl(originalBeatTime.time.beats);
		
		// Core audio clock seems to always be 26ms behind so we offset by -26ms
		uint64_t offset = 26*(NSEC_PER_SEC/1000);
		
		while(running)
		{
			// Notify all who are interested
			[self sendSelectorToListeners:@selector(clockPulseHappened:)];
			
			// Sleep until the next time we want to pulse
			originalBeatTime.time.beats += pulseInterval;
			CAClockTime nextBeatTime;
			CAClockTranslateTime(caClock, &originalBeatTime, kCAClockTimeFormat_HostTime, &nextBeatTime);
		//	NSLog(@"%llu - %llu = %llu", nextBeatTime.time.hostTime, offset, nextBeatTime.time.hostTime - offset);
			mach_wait_until(nextBeatTime.time.hostTime - offset);
		}
	};
	
	// Run the clock polling thread
	dispatch_queue_t q_default;
	q_default = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
	dispatch_async(q_default, beatCheckBlock);
	
	[self sendSelectorToListeners:@selector(clockDidStart:)];
}
- (void)stop
{
	CAClockStop(caClock);
	running = NO;
	[self sendSelectorToListeners:@selector(clockDidStop:)];
}
- (void)arm
{
	//
	// Arm the clock and go!
	OSErr err = 0;
	err = CAClockArm(caClock);
	if(err)
		NSLog(@"Couldn't arm clock!");
}
- (void)disarm
{
	[self stop];
	OSErr err = 0;
	err = CAClockDisarm(caClock);
	if(err)
		NSLog(@"Couldn't disarm clock!");
}

- (void)setInternalBPM:(CAClockTempo)inTempo
{
	OSErr err;
	internalBPM = inTempo;
	
	// Create a 4/4 tempo map with the passed bpm
	CATempoMapEntry tempoMap;
	tempoMap.beats = 4.0;
	tempoMap.tempoBPM = internalBPM;
	err = CAClockSetProperty(caClock, kCAClockProperty_TempoMap, sizeof(CATempoMapEntry), &tempoMap);
	if(err)
		NSLog(@"Error setting clock tempomap (in %f err %d)", internalBPM, err);
}
- (CAClockTempo)internalBPM
{
	return internalBPM;
}
- (void)setSyncMode:(CAClockSyncMode)syncMode
{
	OSErr err;
	err = CAClockSetProperty(caClock, kCAClockProperty_SyncMode, sizeof(CAClockSyncMode), &syncMode);
	if(err)
		NSLog(@"Error setting clock syncmode");	
}
- (void)setMIDISyncSource:(NSString *)name
{
	OSErr err;
	CFStringRef srcDisplayName;
	unsigned numberOfSources = MIDIGetNumberOfSources();
	if(numberOfSources == 0)
	{
		NSLog(@"No MIDI sources found!");
		return;
	}
	
	// if no source name is passed, just use the first one
	MIDIEndpointRef currPoint;
	if(!name)
	{
		currPoint= MIDIGetSource(0);
		return;
	}
	
	currPoint = NULL;
	for(int i = 0; i < numberOfSources; ++i)
	{
		currPoint = MIDIGetSource(i);
		err = MIDIObjectGetStringProperty(currPoint, kMIDIPropertyDisplayName, &srcDisplayName);
		if (err) 
			NSLog(@"MIDI Get sourceName err = %d", err);
				
		if([(NSString *)srcDisplayName isEqualToString:name])
		{
			// Tell the CoreAudio clock to use the source
			srcPointRef = currPoint;
			err = CAClockSetProperty(caClock, kCAClockProperty_SyncSource, sizeof(srcPointRef), &srcPointRef);
			if(err)
				NSLog(@"Error setting clock midi sync source %d", err);	
			NSLog(@"connect = %@", srcDisplayName);
				CFRelease(srcDisplayName);
			break;
		}
		CFRelease(srcDisplayName);
	}
	// If we dont find the wanted one fall back on the first one
	if(!currPoint)
		currPoint= MIDIGetSource(0);
}

#pragma mark -
// Status query methods

- (CAClockBeats)currentBeat
{
	CAClockTime beatTime;
	CAClockGetCurrentTime(caClock, kCAClockTimeFormat_Beats, &beatTime);
	
	return beatTime.time.beats;
}
- (CAClockTempo)currentBPM
{
	CAClockTempo tempo; // Internal tempo
	CAClockTime  timestamp;
	CAClockGetCurrentTempo(caClock, &tempo, &timestamp);
	// We have to multiply the internal BPM with the playback rate to get the actual playback BPM
	Float64 playrate;
	CAClockGetPlayRate(caClock, &playrate);
	tempo *= playrate; // The synced tempo
	
	return tempo;
}

// Makes the clock pulse listeners perform a selector
- (void)sendSelectorToListeners:(SEL)selector
{
	for(id<NSObject,PSClockListener>listener in self.listeners)
	{
		if([listener respondsToSelector:selector])
			[listener performSelector:selector withObject:self];
	}
}
#pragma mark -
// CoreAudio Clock handling

// Receives status change notifications from the CoreAudio Clock
- (void)clockListener:(CAClockMessage)message parameter:(const void *)param
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	switch (message) {
		case kCAClockMessage_Started:
			NSLog(@"Clock started");
			running = YES;
			[self start];
			break;
		case kCAClockMessage_Stopped:
			NSLog(@"Clock stopped");
			[self stop];
			break;
		case kCAClockMessage_Armed:
			NSLog(@"Clock armed");
			break;
		case kCAClockMessage_Disarmed:
			NSLog(@"Clock disarmed");
			break;
		case kCAClockMessage_WrongSMPTEFormat:
			NSLog(@"Clock received wrong SMPTE format");
			break;
		case kCAClockMessage_StartTimeSet:
			NSLog(@"Clock start time set");
			break;
		default:
			NSLog(@"Unknown clock message received: %@", [(NSString *)UTCreateStringForOSType(message) autorelease]);
			break;
	}
	
	[pool drain];
}

// These 2 methods handle setting the absolute timecode when it's received
// Not really tested since I've never had to use it, but should work
- (void)setCurrentTime:(NSNumber *)secondsNumber
{
	NSLog(@"set current time code?");
	CAClockSeconds seconds = [secondsNumber doubleValue];
	if (!running) {
		
		CAClockTime time;
		time.format = kCAClockTimeFormat_Seconds;
		time.time.seconds = seconds;
		
		OSStatus err = CAClockSetCurrentTime(caClock, &time);
		if (err != noErr)
			NSLog(@"set setCurrentTime err");
	}
	else
		keepSeconds = seconds;
}

- (void)setFullTimecode:(MIDIPacket *)packet
{
	OSStatus err;
	
	SMPTETime smpteTime;
	smpteTime.mType = kSMPTETimeType30;
	smpteTime.mHours = packet->data[5] & 0x0F;
	smpteTime.mMinutes = packet->data[6];
	smpteTime.mSeconds = packet->data[7];
	smpteTime.mFrames = packet->data[8];
	smpteTime.mSubframeDivisor = 80;
	smpteTime.mSubframes = 0;
	
	CAClockSeconds seconds;
	err = CAClockSMPTETimeToSeconds(caClock, &smpteTime, &seconds);
	if (err != noErr) {
		NSLog(@"SMPTETimeToSecond err = %d", err);
		return;
	}
	
	NSNumber *secondsNumber = [NSNumber numberWithDouble:seconds];
	[self performSelectorOnMainThread:@selector(setCurrentTime:) 
												 withObject:secondsNumber 
											waitUntilDone:NO];
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


- (void)dealloc
{
	OSStatus err;
	
	err = MIDIPortDisconnectSource(inputPortRef, srcPointRef);
	if (err != noErr) NSLog(@"MIDIPortDisconnectSource Err"); 
	err = MIDIPortDispose(inputPortRef);
	if (err != noErr) NSLog(@"MIDIPortDispose Err");
	err = MIDIClientDispose(clientRef);
	if (err != noErr) NSLog(@"MIDIClientDispose Err");
	
	err = CAClockDisarm(caClock);
	if (err != noErr) NSLog(@"clock disarm Err");
	err = CAClockDispose(caClock);
	if (err != noErr) NSLog(@"CAClockDispose err");
	
	[super dealloc];
}	
@end

static void MIDIInputProc(const MIDIPacketList *pktlist, void *readProcRefCon, void *srcConnRefCon)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	// Make a pointer to the first packet
	MIDIPacket *packet = (MIDIPacket *)&(pktlist->packet[0]);
	UInt32 packetCount = pktlist->numPackets;
	
	for (NSInteger i = 0; i < packetCount; i++) {
		// If the packet contains a full timecode, assign it
		if ((packet->data[0] == 0xF0) &&
				(packet->data[1] == 0x7F) && 
				(packet->data[2] == 0x7F) && 
				(packet->data[3] == 0x01) && 
				(packet->data[4] == 0x01))
		{
			[(id)readProcRefCon setFullTimecode:packet];
		}
		
		// Onto the next packet
		packet = MIDIPacketNext(packet);
	}
	
	[pool drain];
}

// Just forwards the message to the instance method
static void clockListener(void *userData, CAClockMessage message, const void *param)
{
	[(id)userData clockListener:message parameter:param];
}