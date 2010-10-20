////////////////////////////////////////////////////////////////////////////////////////////
//
//  PadKontrolConstants
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
// SysEX command codes for the KORG PadKontrol
// See .c file for more info

#import <stdint.h>

#pragma mark -
#pragma mark BUILDING BLOCKS
// Common prefix for building any command
extern const uint8_t kPKMessagePrefix[5];
extern const uint8_t kEndOfExclusive_code;

#pragma mark -
#pragma mark OUTPUT COMMANDS

// Make the PK enter Native mode so we get full control
extern const uint8_t kInitNative[9];
// Send the PK back into standard mode (no sysex messages/control over lights)
extern const uint8_t kExitNative[9];

// The init lights commands both initialize all the lights, only difference being
// wether they're on or off after
extern const uint8_t kInitLightsOn_code[18];
extern const uint8_t kInitLightsOff_code[18];

// Tells the PK to start sending data for button pushes (SysEX on Port A and Notes on Port B)
extern const uint8_t kDataInit_code[50];

extern const uint8_t kTotalInit_code[89];

// Control button/pad lights
// Light control command format: <cmdprefix> 0x01 <pad/button code> <light state> <end of exclusive>
// You can also "draw" on the LED monitor by passing in the LED codes. but you'll probably want to
// use the LED character readout command
extern const uint8_t kLightControlCommand_code;

extern const uint8_t kPad_lightOff_code;
extern const uint8_t kPad_blink_code;
extern const uint8_t kPad_lightOn_code;
// Note on oneshots, you can send any value between 0x41 & 0x5f for different lengths
extern const uint8_t kPad_shortOneshot_code;
extern const uint8_t kPad_longOneshot_code;

extern const uint8_t kPad_lightCommandTemplate_code[9];
const uint8_t kMultipleLightCommandTemplate_code[18];
const uint8_t kMultipleLightGroup[7];

// Control the LED readout
// Command format: <cmdprefix> 0x22 0x04 <LED State> aa bb cc <end of exclusive>
// aa bb and cc are ASCII characters, a-z A-Z 0-9 and - are allowed characters.
const uint8_t kLEDReadoutCommandTemplate_code[12];
extern const uint8_t kLEDStateOn_code;
extern const uint8_t kLEDStateBlink_code;

#pragma mark - 
#pragma mark INPUT MESSAGES
// Pad hit message: <cmdprefix> 0x45 <pad code on/off> <velocity> <end of exclusive>
extern const uint8_t kPadHitCommand_code;
// Button pushed/released message: <cmdprefix> 0x48 <button code> <on/off: 0x00/0x7f> <end of exclusive>
extern const uint8_t kButtonPushCommand_code;
// Knob turned message: <cmdprefix> 0x49 <knob code> <knob value: 0x00-0x7f> <end of exclusive>
extern const uint8_t kKnobTurnCommand_code;
// Rotary encoder turned message: <cmdprefix> 0x43 0x00 <knob direction> <end of exclusive>
extern const uint8_t kEncoderTurnCommand_code;
extern const uint8_t kEncoderDirectionLeft;
extern const uint8_t kEncoderDirectionRight;
// X/Y Pad Pressed/Released message: <cmdprefix> 0x48 <on/off: 0x00/0x7f> <end of exclusive>
extern const uint8_t kXYPadPressed_code;
// X/Y Pad finger moved message: <cmdprefix> 0x4B <x value: 0x00-0x7f> <y value: 0x00-0x7f> <end of exclusive>
extern const uint8_t kXYPadMove;


#pragma mark -
#pragma mark IDENTIFIERS
// Codes for each button/pad (On transmitted when a pad is hit, Off when its released)
extern const uint8_t kPadOn_codes[16];
extern const uint8_t kPadOff_codes[16];

// OUTPUT CODES 
// (when we receive a button press message the codes are totally different, PSPadKontrol handles the conversion)
extern const uint8_t kSceneBtn_code;
extern const uint8_t kMessageBtn_code;
extern const uint8_t kSettingBtn_code;
extern const uint8_t kNoteCCBtn_code;
extern const uint8_t kMidiCHBtn_code;
extern const uint8_t kSWTypeBtn_code;
extern const uint8_t kRelValBtn_code;
extern const uint8_t kVelocityBtn_code;
extern const uint8_t kPortBtn_code;
extern const uint8_t kFixedVelBtn_code;
extern const uint8_t kProgChangeBtn_code;
extern const uint8_t kXBtn_code;
extern const uint8_t kYBtn_code;
extern const uint8_t kKnobAssignOneBtn_code;
extern const uint8_t kKnobAssignTwoBtn_code;
extern const uint8_t kPedalBtn_code;
extern const uint8_t kRollBtn_code;
extern const uint8_t kFlamBtn_code;
extern const uint8_t kHoldBtn_code;

extern const uint8_t kKnobOne_code;
extern const uint8_t kKnobTwo_code;

extern const uint8_t kXYPad_code;

// LED Left letter 0x38-3E
extern const uint8_t kLED1_codes[7];
// LED Middle letter 0x30-36
extern const uint8_t kLED2_codes[7];
// LED Right letter 0x40-46
extern const uint8_t kLED3_codes[7];
//Punctuation
extern const uint8_t kLEDLeftDot_code;
extern const uint8_t kLEDMiddleDot_code;
extern const uint8_t kLEDRightDot_code;

