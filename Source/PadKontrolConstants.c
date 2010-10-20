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
// Format of an sysex message to/from the PadKONTROL:
// F0* 42* 40* 6E* 08* cd nn dd F7  - Bytes marked by * are constant in all messages.
//
// F0: Exclusive status byte, 42: KORG manufacturer identifier, 40: Device ID
// 6E: Means software project (Family ID), not sure about the significance (but it's constant so it doesn't really matter)
// 08: PadKONTROL (SubID)
// cd: Bits: 0dvx xxxx
//       d: 1 => Controller->Host
//       v: 0 => 2 Bytes data format, 1 => Variable
//   xxxxx: Command Number
// nn: 2 Bytes data format => Operation Number, Variable: Data size
// dd: Data (If variable data format this part will be as long as indicated by the Data size in nn)
// F7: End of exclusive

// Command templates are full commands that just need certain bytes within them replaced before they can be
// sent as a SysEx command.

// For further reference read: 
// https://docs.google.com/viewer?url=http://www.thecovertoperators.org/uploads/PadKONTROL%2520imp.pdf

#import "PadKontrolConstants.h"

#pragma mark -
#pragma mark BUILDING BLOCKS
// Common prefix for building any command
// When receiving messages the F0 from the controller is usually omitted
const uint8_t kPKMessagePrefix[5]  = {0xF0, 0x42, 0x40, 0x6E, 0x08};
const uint8_t kEndOfExclusive_code = 0xF7;

#pragma mark -
#pragma mark OUTPUT COMMANDS

// Make the PK enter Native mode so we get full control
const uint8_t kInitNative[9] = {0xF0, 0x42, 0x40, 0x6E, 0x08, 0x00, 0x00, 0x01, 0xF7};
// Send the PK back into standard mode (no sysex messages/control over lights)
const uint8_t kExitNative[9] = {0xF0, 0x42, 0x40, 0x6E, 0x08, 0x00, 0x00, 0x00, 0xF7};

// The init lights commands both initialize all the lights, only difference being
// wether they're on or off after
const uint8_t kInitLightsOn_code[18]  = {0xF0, 0x42, 0x40, 0x6E, 0x08, 0x3F, 0x0A, 0x01, 0x7F, 0x7F, 0x7F, 0x7F, 0x7F, 0x03, 0x38, 0x38, 0x38, 0xF7};
const uint8_t kInitLightsOff_code[18] = {0xF0, 0x42, 0x40, 0x6E, 0x08, 0x3F, 0x0A, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x38, 0x38, 0x38, 0xF7};

// Tells the PK to start sending data for button pushes (SysEX on Port A and Notes on Port B)
const uint8_t kDataInit_code[50]  = {0xF0, 0x42, 0x40, 0x6E, 0x08, 0x3F, 0x2A, 0x00, 0x00, 0x05, 0x05, 0x05, 0x7F, 0x7E, 0x7F, 0x7F, 0x03, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0xF7};

const uint8_t kTotalInit_code[89] = {0xF0, 0x42, 0x40, 0x6E, 0x08, 0x00, 0x00, 0x01, 0xF7, 0xF0, 0x42, 0x40, 0x6E, 0x08, 0x3F, 0x0A, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x38, 0x38, 0x38, 0xF7, 0xF0, 0x42, 0x40, 0x6E, 0x08, 0x3F, 0x2A, 0x00, 0x00, 0x05, 0x05, 0x05, 0x7F, 0x7E, 0x7F, 0x7F, 0x03, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x0A, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0xF7, 0xF0, 0x42, 0x40, 0x6E, 0x08, 0x22, 0x04, 0x00, 0x50, 0x57, 0x4E, 0xF7};

// Control button/pad lights
// Light control command format: <cmdprefix> 0x01 <pad/button code> <light state> <end of exclusive>
// You can also "draw" on the LED monitor by passing in the LED codes. but you'll probably want to
// use the LED character readout command
const uint8_t kLightControlCommand_code = 0x01;
// Sets more than one light's status simultaneously
// Format: <cmdprefix> 0x3F 0x0A, 0x01 aa bb cc dd ee 00 xx xx xx
// aa bb cc dd and ee are each a bitmask defining which light in a group is lit (see below)
// xx yy zz: is the LED readout (ASCII)
const uint8_t kMultipleLightCommandTemplate_code[18] = {0xF0, 0x42, 0x40, 0x6E, 0x08, 0x3F, 0x0A, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x29, 0x29, 0x29, 0xF7};
// When making a multiple we make 5 1 byte bitmasks, 5 groups if you will
// I'm too lazy to make variables for each, so just use this group array and use the comments below as reference
// Group 1: Pad 1-7
// Group 2: Pad 8-14
// Group 3: Pad 15-15,                Scene,         Message,       Settings, Note/CC#,   Midi Ch.
// Group 4: SW Type,   Rel. Val,      Velocity,      Port,     Fixed Vel., Prgrm Change, X Button
// Group 5: Y Button , Knob Assign 1, Knob Assign 2, Pedal,    Roll,       Flam,         Hold

// So to light pads 2 and 4 you would pass kMultipleLightGroup[1] | kMultipleLightGroup[3] as group 1
// to PadKontrol's controlMultipleLights. Use -buildMultipleLightControlMaskFrom[...] to build the command
// from the masks automatically.
const uint8_t kMultipleLightGroup[7] = {0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40};


const uint8_t kPad_lightOff_code = 0x00;
const uint8_t kPad_blink_code    = 0x63;
const uint8_t kPad_lightOn_code  = 0x20;
// Note on oneshots, you can send any value between 0x41 & 0x5f for different lengths
const uint8_t kPad_shortOneshot_code          = 0x41;
const uint8_t kPad_longOneshot_code           = 0x5f;

// Third byte from the right is the button/pad identifier, Second from the right is the light state(see above)
const uint8_t kPad_lightCommandTemplate_code[9] = {0xf0, 0x42, 0x40, 0x6e, 0x08, 0x01, 0x00, 0x00, 0xf7};

// Control the LED readout
// Command format: <cmdprefix> 0x22 0x04 <LED State> aa bb cc <end of exclusive>
// aa bb and cc are ASCII characters, a-z A-Z 0-9 and - are allowed characters.
const uint8_t kLEDReadoutCommandTemplate_code[12] = {0xF0, 0x42, 0x40, 0x6E, 0x08, 0x22, 0x04, 0x00, 0x30, 0x30, 0x30, 0xF7};
const uint8_t kLEDStateOn_code           = 0x00;
const uint8_t kLEDStateBlink_code        = 0x01;

#pragma mark - 
#pragma mark INPUT MESSAGES
// Pad hit message: <cmdprefix> 0x45 <pad code on/off> <velocity> <end of exclusive>
const uint8_t kPadHitCommand_code = 0x45;
// Button/XY Pad pushed/released message: <cmdprefix> 0x48 <button code> <on/off: 0x00/0x7f> <end of exclusive>
const uint8_t kButtonPushCommand_code = 0x48;
// Knob turned message: <cmdprefix> 0x49 <knob code> <knob value: 0x00-0x7f> <end of exclusive>
const uint8_t kKnobTurnCommand_code = 0x49;
// Rotary encoder turned message: <cmdprefix> 0x43 0x00 <knob direction> <end of exclusive>
const uint8_t kEncoderTurnCommand_code = 0x43;
const uint8_t kEncoderDirectionLeft    = 0x7f;
const uint8_t kEncoderDirectionRight   = 0x01;
// X/Y Pad finger moved message: <cmdprefix> 0x4B <x value: 0x00-0x7f> <y value: 0x00-0x7f> <end of exclusive>
const uint8_t kXYPadMove         = 0x4B;


#pragma mark -
#pragma mark IDENTIFIERS
// Codes for each button/pad (On transmitted when a pad is hit, Off when its released)
const uint8_t kPadOn_codes[16]  = {0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F};
const uint8_t kPadOff_codes[16] = {0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F};

const uint8_t kSceneBtn_code         = 0x10;
const uint8_t kMessageBtn_code       = 0x11;
const uint8_t kSettingBtn_code       = 0x12;
const uint8_t kNoteCCBtn_code        = 0x13;
const uint8_t kMidiCHBtn_code        = 0x14;
const uint8_t kSWTypeBtn_code        = 0x15;
const uint8_t kRelValBtn_code        = 0x16;
const uint8_t kVelocityBtn_code      = 0x17;
const uint8_t kPortBtn_code          = 0x18;
const uint8_t kFixedVelBtn_code      = 0x19;
const uint8_t kProgChangeBtn_code    = 0x1A;
const uint8_t kXBtn_code             = 0x1B;
const uint8_t kYBtn_code             = 0x1C;
const uint8_t kKnobAssignOneBtn_code = 0x1D;
const uint8_t kKnobAssignTwoBtn_code = 0x1E;
const uint8_t kPedalBtn_code         = 0x1F;
const uint8_t kRollBtn_code          = 0x20;
const uint8_t kFlamBtn_code          = 0x21;
const uint8_t kHoldBtn_code          = 0x22;

const uint8_t kKnobOne_code = 0x00;
const uint8_t kKnobTwo_code = 0x01;

const uint8_t kXYPad_code = 0x20;


// LED Left letter 0x38-3E
const uint8_t kLED1_codes[7] = {0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E};
// LED Middle letter 0x30-36
const uint8_t kLED2_codes[7] = {0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36};
// LED Right letter 0x40-46
const uint8_t kLED3_codes[7] = {0x40, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46};
//Punctuation
const uint8_t kLEDLeftDot_code   = 0x03F;
const uint8_t kLEDMiddleDot_code = 0x037;
const uint8_t kLEDRightDot_code  = 0x047;

