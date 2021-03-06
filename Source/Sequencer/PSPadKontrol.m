////////////////////////////////////////////////////////////////////////////////////////////
//
//  PSPadKontrol
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

#import "PSPadKontrol.h"
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSECombinationOutputStream.h"

#import "PadKontrolConstants.h"
#import "PSPadKontrolEvent.h"

#import <mach/mach_time.h>

PSPadKontrol *sharedPadKontrol;

@interface PSPadKontrol ()
- (void)_transmitEvent:(PSPadKontrolEvent *)anEvent;
- (uint8_t)_convertIncomingButtonCodeToOutputOne:(uint8_t)inCode;
@end

@implementation PSPadKontrol
@synthesize outputStream=_outputStream, inputStream=_inputStream, eventListeners=_eventListeners;

+ (PSPadKontrol *)sharedPadKontrol {
	if(!sharedPadKontrol)
		sharedPadKontrol = [[self alloc] init];
	return [[sharedPadKontrol retain] autorelease];
}

- (id)init {
	return [self initWithInputCTRL:kPSPadKontrolCTRLDeviceName 
                           portA:kPSPadKontrolPortADeviceName 
                           portB:kPSPadKontrolPortBDeviceName];
}
- (id)initWithInputCTRL:(NSString *)ctrlDeviceName portA:(NSString *)portAName portB:(NSString *)portBName {
	if(!(self = [super init]))
		return nil;
	_eventListeners = [[NSMutableArray alloc] init];
	_ledValue = malloc(sizeof(uint8_t)*4);

	//
	// Set up the output stream
	_outputStream = [[SSECombinationOutputStream alloc] init];
	
	[_outputStream setSendsSysExAsynchronously:YES];
	[_outputStream setIgnoresTimeStamps:NO];
	[_outputStream setVirtualDisplayName:@"Sekwenser output"];
	//[center addObserver:self selector:@selector(outputStreamSelectedDestinationDisappeared:) name:SSECombinationOutputStreamSelectedDestinationDisappearedNotification object:self.outputStream];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willStartSendingSysEx:) name:SMPortOutputStreamWillStartSysExSendNotification object:self.outputStream];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSendSysEx:) name:SMPortOutputStreamFinishedSysExSendNotification object:self.outputStream];
	
	
	// Choose the CTRL bus of the padkontrol (for sending sysex messages to the controller)
	NSArray *destinations = [_outputStream destinations];
	for(id <SSEOutputStreamDestination>dest in destinations) {
		if([[dest outputStreamDestinationName] isEqualToString:ctrlDeviceName]) {
			NSLog(@"Found CTRL bus, assigning");
			[_outputStream setSelectedDestination:dest];
			break;
		}
	}
	
	//
	// Set up the input stream (Listening to the controller)
	_inputStream = [[SMPortInputStream alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readingSysEx:) name:SMInputStreamReadingSysExNotification object:self.inputStream];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readingSysEx:) name:SMInputStreamDoneReadingSysExNotification object:self.inputStream];
	[_inputStream setMessageDestination:self];
	
	for(SMSourceEndpoint *endpoint in [SMSourceEndpoint sourceEndpoints]) {
		if([[endpoint inputStreamSourceName] isEqualToString:portAName]
			 || [[endpoint inputStreamSourceName] isEqualToString:portBName]) {
			[_inputStream addEndpoint:endpoint];
			NSLog(@"Found Port A (SysEx input)");
		}
	}
	
	return self;
}
- (void)dealloc {
  [_outputStream release];
  [_inputStream release];
  [_eventListeners release];
	free(_ledValue);
	
	[super dealloc];
}

#pragma mark -
// Listeners
- (void)registerEventListener:(id)listener {
  [_eventListeners addObject:listener];
}
- (void)unregisterEventListener:(id)listener {
  [_eventListeners removeObject:listener];
}

#pragma mark -
// PadKONTROL communication
- (void)enterNativeMode {
	[self sendSysexCommand:kTotalInit_code size:sizeof(kTotalInit_code)];
	[self clearLED];
	
	PSPadKontrolEvent *event = [PSPadKontrolEvent eventWithDevice:self
                                                           type:PSPadKontrolEnteredNativeMode
                                                       velocity:0
                                                         values:NULL
                                                 numberOfValues:0
                                                    affectedPad:-1
                                             affectedEntityCode:0];
	[self _transmitEvent:event];
}

- (void)exitNativeMode {
	NSLog(@"Exiting native mode");
	[self sendSysexCommand:kExitNative size:sizeof(kExitNative)];
}

- (void)resetAllLights {
    [self clearLED];
	uint8_t mask[5] = {0};
    [self controlMultipleLights:mask ledMask:mask];
}

- (void)controlLight:(const uint8_t *)lightIdentifier state:(const uint8_t *)lightState {
	uint8_t *lightCommand = alloca(sizeof(kPad_lightCommandTemplate_code));
	memcpy(lightCommand, kPad_lightCommandTemplate_code, sizeof(kPad_lightCommandTemplate_code));
	memcpy(lightCommand+6, lightIdentifier, 1);
	memcpy(lightCommand+7, lightState, 1);
	
	[self sendSysexCommand:lightCommand size:sizeof(kPad_lightCommandTemplate_code)];
}

// Button mask is 5 bytes, led mask is 3 bytes
- (void)controlMultipleLights:(const uint8_t *)buttonMask ledMask:(const uint8_t *)ledMask {
	// the mask is 5 bytes
	uint8_t *command = alloca(sizeof(kMultipleLightCommandTemplate_code));
	memcpy(command, kMultipleLightCommandTemplate_code, sizeof(kMultipleLightCommandTemplate_code));
	if(buttonMask)
		memcpy(command+8, buttonMask, sizeof(uint8_t)*5);
	else {
		NSLog(@"no button mask");
	}

	if(ledMask)
		memcpy(command+14, ledMask, sizeof(uint8_t)*3);
	else {
		// For some reason this is reversed, I can't see why endianness would change all of a sudden
		// Though.. Anyway, it works if we reverse the stored led value
		memcpy(command+14, _ledValue+2, sizeof(uint8_t));
		memcpy(command+15, _ledValue+1, sizeof(uint8_t));
		memcpy(command+16, _ledValue, sizeof(uint8_t));
	}

	//NSLog(@"multicmd %@", [NSData dataWithBytes:command length:sizeof(kMultipleLightCommandTemplate_code)]);
	[self sendSysexCommand:command size:sizeof(kMultipleLightCommandTemplate_code)];
}
// Convenience function to build a mask for multiple light control
- (uint8_t *)buildMultipleLightControlMaskFromGroupOne:(const uint8_t *)maskOne 
																									 two:(const uint8_t *)maskTwo 
																								 three:(const uint8_t *)maskThree
																									four:(const uint8_t *)maskFour
																									five:(const uint8_t *)maskFive

{
	uint8_t *mask = calloc(5, sizeof(uint8_t)); // Use calloc to get a zeroed mask
	if(maskOne)
		memcpy(mask,   maskOne, sizeof(uint8_t));
	if(maskTwo)
		memcpy(mask+1, maskTwo, sizeof(uint8_t));
	if(maskThree)
		memcpy(mask+2, maskThree, sizeof(uint8_t));
	if(maskFour)
		memcpy(mask+3, maskFour, sizeof(uint8_t));
	if(maskFive)
		memcpy(mask+4, maskFive, sizeof(uint8_t));
	
	return mask;
}
- (void)setLEDString:(const char *)string blink:(BOOL)blink {
    char *buf = strndup(string, 4);
	for(int i = 0; i < 3; ++i) {
		if(*(buf + i) == 0x00)
			*(buf + i) = 0x29;
	}
	uint8_t *command = alloca(sizeof(kLEDReadoutCommandTemplate_code));
	memcpy(command, kLEDReadoutCommandTemplate_code, sizeof(kLEDReadoutCommandTemplate_code));
	uint8_t status = kLEDStateOn_code;
	if(blink)
		status = kLEDStateBlink_code;
	memcpy(command+7, &status, sizeof(uint8_t));
	memcpy(command+8, buf, sizeof(uint8_t)*3);
	
	memcpy(_ledValue, buf, sizeof(uint8_t)*3);
	[self sendSysexCommand:command size:sizeof(kLEDReadoutCommandTemplate_code)];
}
- (void)setLEDNumber:(NSInteger)number blink:(BOOL)blink {
	char *numStr = malloc(sizeof(char)*4);
	if((number >= 0) && (number < 1000))
		snprintf(numStr, sizeof(uint8_t)*4, "%3.d", number);
	else if((number <= 0) && (number > -100))
		snprintf(numStr, sizeof(uint8_t)*4, "-%2.d", number);
	else {
		NSLog(@"%d is out of range for the PadKontrol LED(-99 - 999)", number);
		snprintf(numStr, sizeof(uint8_t)*4, "err");
	}

	[[PSPadKontrol sharedPadKontrol] setLEDString:numStr blink:blink];
	free(numStr);
}

- (void)clearLED {
	uint8_t clearBytes[3] = {0x29, 0x29, 0x29};
	memcpy(_ledValue, &clearBytes, sizeof(uint8_t)*3);
	[[PSPadKontrol sharedPadKontrol] setLEDString:(char*)clearBytes blink:NO];
}

- (BOOL)padIdentifierIsForOnState:(uint8_t *)identifier {
	if(*identifier > kPadOff_codes[15])
		return YES;
	return NO;
}
- (void)handleSysexMessage:(SMSystemExclusiveMessage *)message {
	NSData *data = [message receivedData];
	uint8_t *buffer = malloc([data length]);
	[data getBytes:buffer range:NSMakeRange(0, 1)];
	BOOL statusByteIncluded = NO;
	if(*buffer == 0xf0)
		statusByteIncluded = YES;
	// We add statusByteIncluded to the locations because if it is then everything is shifted 1 to the right
	NSUInteger commandLoc = 4 + statusByteIncluded;
	[data getBytes:buffer range:NSMakeRange(commandLoc, 1)];
	uint8_t command = *buffer;
	//NSLog(@"Command: %x", command);
	
	// Construct an event
	PSPadKontrolEvent *event;
	PSPadKontrolEventType eventType;
	PSPadKontrolVelocity eventVelocity = 0x00;
	PSPadKontrolValue *eventValues = 0x00;
	NSUInteger numberOfEventValues = 0;
	NSInteger affectedPad = -1;
	uint8_t affected_entity_code = 0x00;
	
	if(command == kPadHitCommand_code) {
		uint8_t *padInfo = malloc(sizeof(uint8_t)*2);
		[data getBytes:padInfo range:NSMakeRange(commandLoc+1, 2)];

		affected_entity_code = *padInfo;
		if([self padIdentifierIsForOnState:padInfo]) {
			//NSLog(@"Pad hit %d - %d", *padInfo, *(padInfo+1));
			//uint8_t state = 0x45;
			//[self controlLight:padInfo state:&state];
			eventType = PSPadKontrolPadPressEventType;
			affectedPad = *padInfo - 0x40;
			eventVelocity = *(padInfo+1);
		}
		else {
			eventType = PSPadKontrolPadReleaseEventType;
			affectedPad = *padInfo;
		}
	}
	else if(command == kButtonPushCommand_code) {
        uint8_t buttonInfo[2];
		[data getBytes:buttonInfo range:NSMakeRange(commandLoc+1, 2)];
		
		affected_entity_code = *buttonInfo;
		affected_entity_code = [self _convertIncomingButtonCodeToOutputOne:affected_entity_code];
		if(*(buttonInfo+1) == 127) {
		//	NSLog(@"Button pushed %d status %d", *buttonInfo, *(buttonInfo+1));
			eventType = PSPadKontrolButtonPressEventType;
			if(*buttonInfo == kXYPad_code)
				eventType = PSPadKontrolXYPadPressEventType;
		}
		else {
		//	NSLog(@"Button released %d status %d", *buttonInfo, *(buttonInfo+1));
			eventType = PSPadKontrolButtonReleaseEventType;
			if(*buttonInfo == kXYPad_code)
				eventType = PSPadKontrolXYPadReleaseEventType;
		}

	}
	else if(command == kKnobTurnCommand_code) {
		uint8_t knobInfo[2];
		[data getBytes:knobInfo range:NSMakeRange(commandLoc+1, 2)];
		
		affected_entity_code = *knobInfo;
		//NSLog(@"Knob turn %d %d", *knobInfo, *(knobInfo+1));
		eventType = PSPadKontrolKnobTurnEventType;
		numberOfEventValues = 1;
		eventValues = malloc(sizeof(PSPadKontrolValue));
		memcpy(eventValues, (knobInfo+1), sizeof(PSPadKontrolValue));
	}
	else if(command == kEncoderTurnCommand_code) {
		uint8_t encoderInfo[2];
		[data getBytes:encoderInfo range:NSMakeRange(commandLoc+1, 2)];
		
		affected_entity_code = encoderInfo[0];
		//NSLog(@"Encoder turn %d", *(encoderInfo+1));
		eventType = PSPadKontrolEncoderTurnEventType;
		numberOfEventValues = 1;
		eventValues = malloc(sizeof(PSPadKontrolValue));
		memcpy(eventValues, (encoderInfo+1), sizeof(PSPadKontrolValue));
	}
	else if(command == kXYPadMove) {
		uint8_t *xyPadInfo[2];
		[data getBytes:xyPadInfo range:NSMakeRange(commandLoc+1, 2)];
		
		//NSLog(@"XY Pad moved %d %d", *xyPadInfo, *(xyPadInfo+1));

		eventType = PSPadKontrolXYPadMoveEventType;
		affected_entity_code = kXYPad_code;
		numberOfEventValues = 2;
		eventValues = malloc(sizeof(PSPadKontrolValue)*2);
		memcpy(eventValues, xyPadInfo, sizeof(PSPadKontrolValue)*2);
	}
	else {
		//NSLog(@"Unknown command received from PadKONTROL");
		free(buffer);
		return;
	}
	free(buffer);
	
	event = [PSPadKontrolEvent eventWithDevice:self
                                        type:eventType
                                    velocity:eventVelocity
                                      values:eventValues
                              numberOfValues:numberOfEventValues
                                 affectedPad:affectedPad
                          affectedEntityCode:affected_entity_code];
	[self _transmitEvent:event];
}

- (void)_transmitEvent:(PSPadKontrolEvent *)anEvent {
	for(id<PSPadKontrolEventListener> listener in self.eventListeners) {
		if(![listener padKontrolEventReceived:anEvent fromPadKontrol:self])
            return;
	}
}
//
// MIDI interface
- (void)sendSysexCommand:(const uint8_t *)command size:(NSUInteger)commandSize {
//	uint8_t *message = malloc(commandSize);
//	memcpy(message, command, commandSize);

	//NSLog(@"init message frag %x %x %x %x %x %x %x %x %x %x %x %x %x", *message, *(message+1), *(message+2), *(message+3), *(message+4), *(message+5), *(message+6), *(message+7), *(message+8), *(message+9), *(message+10), *(message+11), *(message+12));
	NSData *data = [NSData dataWithBytes:command length:commandSize];
	//NSLog(@"nsdata %@ size %d", [data description], commandSize);
	
	NSArray *messages = [SMSystemExclusiveMessage systemExclusiveMessagesInData:data];
	//NSLog(@"sending sysex messages %@", messages);
	[_outputStream takeMIDIMessages:messages];
}

- (void)readingSysEx:(NSNotification *)notification {
	//	NSLog(@"Reading sysex! (%@)", [notification userInfo]);
}

- (void)takeMIDIMessages:(NSArray *)messages {
	for(SMMessage *message in messages) {
		if([message isMemberOfClass:[SMSystemExclusiveMessage class]])
			[self handleSysexMessage:(SMSystemExclusiveMessage *)message];
		// Listen for CC 16 with value 127 CH 16, if received we go back into native mode
		else if([message isMemberOfClass:[SMVoiceMessage class]]) {
			SMVoiceMessage *voiceMessage = (SMVoiceMessage *)message;
			if([voiceMessage status] == SMVoiceMessageStatusControl) {
				if([voiceMessage dataByte1] == 0x10 && [voiceMessage dataByte2] == 0x7f && [voiceMessage matchesChannelMask:SMChannelMask16])
					[self enterNativeMode];
				//NSLog(@"Received cc change %d %d ch %d", [voiceMessage dataByte1], [voiceMessage dataByte2], [voiceMessage channel]);
			}
		}
	}
}

- (void)willStartSendingSysEx:(NSNotification *)notification {
	//NSLog(@"About to send sysex");
}
- (void)didSendSysEx:(NSNotification *)notification {
	//NSLog(@"Sent sysex");
}

// Converts incoming button identifiers to the ones usable to handle lights
- (uint8_t)_convertIncomingButtonCodeToOutputOne:(uint8_t)inCode {
	uint8_t outCode = 0x00;
	switch(inCode) {
		case 0x00:
			outCode = kSceneBtn_code;
			break;
		case 0x01:
			outCode = kMessageBtn_code;
			break;
		case 0x02:
			outCode = kSettingBtn_code;
			break;
		case 0x03:
			outCode = kNoteCCBtn_code;
			break;
		case 0x04:
			outCode = kMidiCHBtn_code;
			break;
		case 0x05:
			outCode = kSWTypeBtn_code;
			break;
		case 0x06:
			outCode = kRelValBtn_code;
			break;
		case 0x07:
			outCode = kVelocityBtn_code;
			break;
		case 0x08:
			outCode = kPortBtn_code;
			break;
		case 0x09:
			outCode = kFixedVelBtn_code;
			break;
		case 0x0A:
			outCode = kProgChangeBtn_code;
			break;
		case 0x0B:
			outCode = kXBtn_code;
			break;
		case 0x0C:
			outCode = kYBtn_code;
			break;
		case 0x0D:
			outCode = kKnobAssignOneBtn_code;
			break;
		case 0x0E:
			outCode = kKnobAssignTwoBtn_code;
			break;
		case 0x0F:
			outCode = kPedalBtn_code;
			break;
		case 0x10:
			outCode = kRollBtn_code;
			break;
		case 0x11:
			outCode = kFlamBtn_code;
			break;
		case 0x12:
			outCode = kHoldBtn_code;
			break;
		default:
			break;
	}
	return outCode;
}
@end
