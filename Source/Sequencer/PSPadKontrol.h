//
//  PSPadKontrol.h
//  sekwenser
//
//  Created by フィヨ on 10/10/11.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//
//  Interface to the PadKONTROL pad controller.
//  Handles I/O (including enabling and disabling the LEDs)
#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>
#import "PSPadKontrolEventListener.h"

#define PSPadKontrolVelocityToFloat(x) ((float)x/127.0)

@class SSECombinationOutputStream;
@class SMPortInputStream;

// I just created these types to make it easier to follow what's going on in the code(make context more apparent)
typedef uint8_t PSPadKontrolVelocity;
// Used for values such as the XY position
typedef uint8_t PSPadKontrolValue;

@interface PSPadKontrol : NSObject <SMMessageDestination> {
	// MIDI interface
	SSECombinationOutputStream *outputStream;
	SMPortInputStream *inputStream;
	
	NSMutableArray *eventListeners;
	
	uint8_t *ledValue;
}
@property(readwrite, retain) SSECombinationOutputStream *outputStream;
@property(readwrite, retain) SMPortInputStream *inputStream;
@property(readwrite, retain) NSMutableArray *eventListeners;

+ (PSPadKontrol *)sharedPadKontrol;
- (id)initWithInputCTRL:(NSString *)ctrlDeviceName portA:(NSString *)portAName portB:(NSString *)portBName;

- (void)controlLight:(uint8_t *)lightIdentifier state:(uint8_t *)lightState;
// Button mask is 5 bytes, led mask is 3 bytes
- (void)controlMultipleLights:(uint8_t *)buttonMask ledMask:(uint8_t *)ledMask;
// Convenience function to build a mask for multiple light control
// You need to free the returned mask yourself
- (uint8_t *)buildMultipleLightControlMaskFromGroupOne:(uint8_t *)maskOne 
																									 two:(uint8_t *)maskTwo 
																								 three:(uint8_t *)maskThree
																									four:(uint8_t *)maskFour
																									five:(uint8_t *)maskFive;
- (void)setLEDString:(uint8_t *)string blink:(BOOL)blink;
- (void)setLEDNumber:(NSInteger)number blink:(BOOL)blink;
- (void)clearLED;

- (void)enterNativeMode;
- (void)exitNativeMode;

// MIDI
- (void)sendSysexCommand:(const uint8_t *)command size:(NSUInteger)commandSize;
@end
