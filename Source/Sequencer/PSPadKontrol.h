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
////////////////////////////////////////////////////////////////////////////////////////////
//  Interface to the PadKONTROL pad controller.
//  Handles I/O (including enabling and disabling the LEDs)

#import <Cocoa/Cocoa.h>
#import <SnoizeMIDI/SMMessageDestinationProtocol.h>
#import "PSPadKontrolEventListener.h"

#define PSPadKontrolVelocityToFloat(x) ((float)x/127.0)

#define kPSPadKontrolCTRLDeviceName @"CTRL"
#define kPSPadKontrolPortADeviceName @"PORT A"
#define kPSPadKontrolPortBDeviceName @"PORT B"

@class SSECombinationOutputStream;
@class SMPortInputStream;

// I just created these types to make it easier to follow what's going on in the code(make context more apparent)
typedef uint8_t PSPadKontrolVelocity;
// Used for values such as the XY position
typedef uint8_t PSPadKontrolValue;

@interface PSPadKontrol : NSObject <SMMessageDestination> {
	// MIDI interface
	SSECombinationOutputStream *_outputStream;
	SMPortInputStream *_inputStream;
	
	NSMutableArray *_eventListeners;
	
	uint8_t *_ledValue;
}
@property(readwrite, retain) SSECombinationOutputStream *outputStream;
@property(readwrite, retain) SMPortInputStream *inputStream;
@property(readwrite, retain) NSMutableArray *eventListeners;

+ (PSPadKontrol *)sharedPadKontrol;
- (id)initWithInputCTRL:(NSString *)ctrlDeviceName portA:(NSString *)portAName portB:(NSString *)portBName;

// Listeners
- (void)registerEventListener:(id)listener;
- (void)unregisterEventListener:(id)listener;

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
- (void)setLEDString:(const char *)string blink:(BOOL)blink;
- (void)setLEDNumber:(NSInteger)number blink:(BOOL)blink;
- (void)clearLED;

- (void)enterNativeMode;
- (void)exitNativeMode;

// MIDI
- (void)sendSysexCommand:(const uint8_t *)command size:(NSUInteger)commandSize;
@end
