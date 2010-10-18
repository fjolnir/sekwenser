//
//  PSPadKontrol.m
//  sekwenser
//
//  Created by フィヨ on 10/10/11.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import "PSPadKontrol.h"
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSECombinationOutputStream.h"

#import "PadKontrolConstants.h"
#import "PSPadKontrolEvent.h"

#import <mach/mach_time.h>

PSPadKontrol *sharedPadKontrol;

@interface PSPadKontrol ()
- (void)transmitEvent:(PSPadKontrolEvent *)anEvent;
- (uint8_t)convertIncomingButtonCodeToOutputOne:(uint8_t)inCode;
@end

@implementation PSPadKontrol
@synthesize outputStream, inputStream, eventListeners;

+ (PSPadKontrol *)sharedPadKontrol
{
	if(!sharedPadKontrol)
		sharedPadKontrol = [[self alloc] init];
	return [[sharedPadKontrol retain] autorelease];
}

- (id)init
{
	return [self initWithInputCTRL:@"CTRL" portA:@"PORT A" portB:@"PORT B"];
}
- (id)initWithInputCTRL:(NSString *)ctrlDeviceName portA:(NSString *)portAName portB:(NSString *)portBName
{
	if(!(self = [super init]))
		return nil;
	self.eventListeners = [NSMutableArray array];
	ledValue = malloc(sizeof(uint8_t)*4);

	//
	// Set up the output stream
	outputStream = [[SSECombinationOutputStream alloc] init];
	
	[self.outputStream setSendsSysExAsynchronously:YES];
	[self.outputStream setIgnoresTimeStamps:NO];
	[self.outputStream setVirtualDisplayName:@"Sekwenser output"];
	//[center addObserver:self selector:@selector(outputStreamSelectedDestinationDisappeared:) name:SSECombinationOutputStreamSelectedDestinationDisappearedNotification object:self.outputStream];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willStartSendingSysEx:) name:SMPortOutputStreamWillStartSysExSendNotification object:self.outputStream];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSendSysEx:) name:SMPortOutputStreamFinishedSysExSendNotification object:self.outputStream];
	
	
	// Choose the CTRL bus of the padkontrol (for sending sysex messages to the controller)
	NSArray *destinations = [self.outputStream destinations];
	for(id <SSEOutputStreamDestination>dest in destinations)
	{
		if([[dest outputStreamDestinationName] isEqualToString:ctrlDeviceName])
		{
			NSLog(@"Found CTRL bus, assigning");
			[self.outputStream setSelectedDestination:dest];
			break;
		}
	}
	
	//
	// Set up the input stream (Listening to the controller)
	inputStream = [[SMPortInputStream alloc] init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readingSysEx:) name:SMInputStreamReadingSysExNotification object:self.inputStream];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(readingSysEx:) name:SMInputStreamDoneReadingSysExNotification object:self.inputStream];
	[self.inputStream setMessageDestination:self];
	
	for(SMSourceEndpoint *endpoint in [SMSourceEndpoint sourceEndpoints])
	{
		if([[endpoint inputStreamSourceName] isEqualToString:portAName]
			 || [[endpoint inputStreamSourceName] isEqualToString:portBName])
		{
			[self.inputStream addEndpoint:endpoint];
			NSLog(@"Found Port A (SysEx input)");
		}
	}
	
	return self;
}	

#pragma mark -
// PadKONTROL communication
- (void)enterNativeMode
{
	[self sendSysexCommand:kTotalInit_code size:sizeof(kTotalInit_code)];
	[self clearLED];
	
	PSPadKontrolEvent *event = [PSPadKontrolEvent eventWithType:PSPadKontrolEnteredNativeMode
																										 velocity:0
																											 values:NULL
																							 numberOfValues:0
																									affectedPad:-1
																					 affectedEntityCode:0];
	[self transmitEvent:event];
}

- (void)exitNativeMode
{
	NSLog(@"Exiting native mode");
	[self sendSysexCommand:kExitNative size:sizeof(kExitNative)];
}

- (void)controlLight:(uint8_t *)lightIdentifier state:(uint8_t *)lightState
{
	uint8_t *lightCommand = malloc(sizeof(kPad_lightCommandTemplate_code));
	memcpy(lightCommand, kPad_lightCommandTemplate_code, sizeof(kPad_lightCommandTemplate_code));
	memcpy(lightCommand+6, lightIdentifier, 1);
	memcpy(lightCommand+7, lightState, 1);
	[self sendSysexCommand:lightCommand size:sizeof(kPad_lightCommandTemplate_code)];
	free(lightCommand);
}

// Button mask is 5 bytes, led mask is 3 bytes
- (void)controlMultipleLights:(uint8_t *)buttonMask ledMask:(uint8_t *)ledMask
{
	// the mask is 5 bytes
	uint8_t *command = malloc(sizeof(kMultipleLightCommandTemplate_code));
	memcpy(command, kMultipleLightCommandTemplate_code, sizeof(kMultipleLightCommandTemplate_code));
	if(buttonMask)
		memcpy(command+8, buttonMask, sizeof(uint8_t)*5);
	else {
		NSLog(@"no button mask");
	}

	if(ledMask)
		memcpy(command+14, ledMask, sizeof(uint8_t)*3);
	else
	{
		// For some reason this is reversed, I can't see why endianness would change all of a sudden
		// Though.. Anyway, it works if we reverse the stored led value
		memcpy(command+14, ledValue+2, sizeof(uint8_t));
		memcpy(command+15, ledValue+1, sizeof(uint8_t));
		memcpy(command+16, ledValue, sizeof(uint8_t));
	}

	//NSLog(@"multicmd %@", [NSData dataWithBytes:command length:sizeof(kMultipleLightCommandTemplate_code)]);
	[self sendSysexCommand:command size:sizeof(kMultipleLightCommandTemplate_code)];
	free(command);
}
// Convenience function to build a mask for multiple light control
- (uint8_t *)buildMultipleLightControlMaskFromGroupOne:(uint8_t *)maskOne 
																									 two:(uint8_t *)maskTwo 
																								 three:(uint8_t *)maskThree
																									four:(uint8_t *)maskFour
																									five:(uint8_t *)maskFive

{
	uint8_t *mask = calloc(5, sizeof(uint8_t));// Use calloc to get a zeroed mask
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
- (void)setLEDString:(uint8_t *)string blink:(BOOL)blink
{
	for(int i = 0; i < 3; ++i)
	{
		if(*(string + i) == 0x00)
			*(string + i) = 0x29;
	}
	uint8_t *command = malloc(sizeof(kLEDReadoutCommandTemplate_code));
	memcpy(command, kLEDReadoutCommandTemplate_code, sizeof(kLEDReadoutCommandTemplate_code));
	uint8_t status = kLEDStateOn_code;
	if(blink)
		status = kLEDStateBlink_code;
	memcpy(command+7, &status, sizeof(uint8_t));
	memcpy(command+8, string, sizeof(uint8_t)*3);
	
	memcpy(ledValue, string, sizeof(uint8_t)*3);
	[self sendSysexCommand:command size:sizeof(kLEDReadoutCommandTemplate_code)];
	free(command);
}
- (void)setLEDNumber:(NSInteger)number blink:(BOOL)blink
{
	char *numStr = malloc(sizeof(char)*4);
	if((number >= 0) && (number < 1000))
		snprintf(numStr, sizeof(uint8_t)*4, "%3.d", number);
	else if((number <= 0) && (number > -100))
		snprintf(numStr, sizeof(uint8_t)*4, "-%2.d", number);
	else
	{
		NSLog(@"%d is out of range for the PadKontrol LED(-99 - 999)", number);
		snprintf(numStr, sizeof(uint8_t)*4, "err");
	}

	[[PSPadKontrol sharedPadKontrol] setLEDString:(uint8_t *)numStr blink:blink];
	free(numStr);
}

- (void)clearLED
{
	uint8_t clearBytes[3] = {0x29, 0x29, 0x29};
	memcpy(ledValue, &clearBytes, sizeof(uint8_t)*3);
	[[PSPadKontrol sharedPadKontrol] setLEDString:clearBytes blink:NO];
}

- (BOOL)padIdentifierIsForOnState:(uint8_t *)identifier
{
	if(*identifier > kPadOff_codes[15])
		return YES;
	return NO;
}
- (void)handleSysexMessage:(SMSystemExclusiveMessage *)message
{
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
	PSPadKontrolValue *eventValues;
	NSUInteger numberOfEventValues = 0;
	NSInteger affectedPad = -1;
	uint8_t affected_entity_code = 0x00;
	
	if(command == kPadHitCommand_code)
	{
		uint8_t *padInfo = malloc(sizeof(uint8_t)*2);
		[data getBytes:padInfo range:NSMakeRange(commandLoc+1, 2)];

		affected_entity_code = *padInfo;
		if([self padIdentifierIsForOnState:padInfo])
		{
			//NSLog(@"Pad hit %d - %d", *padInfo, *(padInfo+1));
			//uint8_t state = 0x45;
			//[self controlLight:padInfo state:&state];
			eventType = PSPadKontrolPadPressEventType;
			affectedPad = *padInfo - 0x40;
			eventVelocity = *(padInfo+1);
		}
		else
		{
			eventType = PSPadKontrolPadReleaseEventType;
			affectedPad = *padInfo;
		}
	}
	else if(command == kButtonPushCommand_code)
	{
		uint8_t *buttonInfo = malloc(sizeof(uint8_t)*2);
		[data getBytes:buttonInfo range:NSMakeRange(commandLoc+1, 2)];
		
		affected_entity_code = *buttonInfo;
		affected_entity_code = [self convertIncomingButtonCodeToOutputOne:affected_entity_code];
		if(*(buttonInfo+1) == 127)
		{
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
	else if(command == kKnobTurnCommand_code)
	{
		uint8_t *knobInfo = malloc(sizeof(uint8_t)*2);
		[data getBytes:knobInfo range:NSMakeRange(commandLoc+1, 2)];
		
		affected_entity_code = *knobInfo;
		//NSLog(@"Knob turn %d %d", *knobInfo, *(knobInfo+1));
		eventType = PSPadKontrolKnobTurnEventType;
		numberOfEventValues = 1;
		eventValues = malloc(sizeof(PSPadKontrolValue));
		memcpy(eventValues, (knobInfo+1), sizeof(PSPadKontrolValue));
	}
	else if(command == kEncoderTurnCommand_code)
	{
		uint8_t *encoderInfo = malloc(sizeof(uint8_t)*2);
		[data getBytes:encoderInfo range:NSMakeRange(commandLoc+1, 2)];
		
		affected_entity_code = *encoderInfo;
		//NSLog(@"Encoder turn %d", *(encoderInfo+1));
		eventType = PSPadKontrolEncoderTurnEventType;
		numberOfEventValues = 1;
		eventValues = malloc(sizeof(PSPadKontrolValue));
		memcpy(eventValues, (encoderInfo+1), sizeof(PSPadKontrolValue));
	}
	else if(command == kXYPadMove)
	{
		uint8_t *xyPadInfo = malloc(sizeof(uint8_t)*2);
		[data getBytes:xyPadInfo range:NSMakeRange(commandLoc+1, 2)];
		
		//NSLog(@"XY Pad moved %d %d", *xyPadInfo, *(xyPadInfo+1));

		eventType = PSPadKontrolXYPadMoveEventType;
		affected_entity_code = kXYPad_code;
		numberOfEventValues = 2;
		eventValues = malloc(sizeof(PSPadKontrolValue)*2);
		memcpy(eventValues, xyPadInfo, sizeof(PSPadKontrolValue)*2);
	}
	else
	{
		//NSLog(@"Unknown command received from PadKONTROL");
		free(buffer);
		return;
	}
	free(buffer);
	
	event = [PSPadKontrolEvent eventWithType:eventType
																	velocity:eventVelocity
																		values:eventValues
														numberOfValues:numberOfEventValues
															 affectedPad:affectedPad
											affectedEntityCode:affected_entity_code];
	[self transmitEvent:event];
}

- (void)transmitEvent:(PSPadKontrolEvent *)anEvent
{
	for(id<PSPadKontrolEventListener> listener in self.eventListeners)
	{
		[listener padKontrolEventReceived:anEvent fromPadKontrol:self];
	}
}
//
// MIDI interface
- (void)sendSysexCommand:(const uint8_t *)command size:(NSUInteger)commandSize
{
	uint8_t *message = malloc(commandSize);
	memcpy(message, command, commandSize);
	
	//NSLog(@"init message frag %x %x %x %x %x %x %x %x %x %x %x %x %x", *message, *(message+1), *(message+2), *(message+3), *(message+4), *(message+5), *(message+6), *(message+7), *(message+8), *(message+9), *(message+10), *(message+11), *(message+12));
	NSData *data = [NSData dataWithBytes:message length:commandSize];
	//NSLog(@"nsdata %@ size %d", [data description], commandSize);
	
	NSArray *messages = [SMSystemExclusiveMessage systemExclusiveMessagesInData:data];
	//NSLog(@"sending sysex messages %@", messages);
	[self.outputStream takeMIDIMessages:messages];
}

- (void)readingSysEx:(NSNotification *)notification
{
	//	NSLog(@"Reading sysex! (%@)", [notification userInfo]);
}

- (void)takeMIDIMessages:(NSArray *)messages
{
	for(SMMessage *message in messages)
	{
		if([message isMemberOfClass:[SMSystemExclusiveMessage class]])
			[self handleSysexMessage:(SMSystemExclusiveMessage *)message];
		// Listen for Control change 0, if received we go back into native mode
		else if([message isMemberOfClass:[SMVoiceMessage class]])
		{
			SMVoiceMessage *voiceMessage = (SMVoiceMessage *)message;
			if([voiceMessage status] == SMVoiceMessageStatusProgram)
			{
				if([voiceMessage dataByte1] == 0x00)
					[self enterNativeMode];
				//NSLog(@"Received program change %d %d", [voiceMessage dataByte1], [voiceMessage dataByte2]);
			}
		}
	}
}

- (void)willStartSendingSysEx:(NSNotification *)notification
{
	//NSLog(@"About to send sysex");
}
- (void)didSendSysEx:(NSNotification *)notification
{
	//NSLog(@"Sent sysex");
}

// Converts incoming button identifiers to the ones usable to handle lights
- (uint8_t)convertIncomingButtonCodeToOutputOne:(uint8_t)inCode
{
	uint8_t outCode = 0x00;
	switch(inCode)
	{
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

- (void)dealloc
{
	free(ledValue);
	
	[super dealloc];
}
@end
