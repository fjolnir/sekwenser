//
//  PSPadKontrolView.h
//  Sekwenser
//
//  Created by フィヨ on 10/10/30.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

// A view abstraction for the padkontrol
// A padkontrol can hold multiple views simultaneously (for example to have one running the pads and one the buttons)
// It's your responsibility to make sure they don't conflict.

#import <Cocoa/Cocoa.h>
#import "PSPadKontrolEventListener.h"

@class PSPadKontrolEvent;

@interface PSPadKontrolView : NSObject <PSPadKontrolEventListener> {
	
}
- (BOOL)isKey;
- (void)makeKey;
- (void)resignKey;

- (void)padKontrolReady;

- (void)updateLights;

// Event handlers
- (void)padPressed:(PSPadKontrolEvent *)event;
- (void)padReleased:(PSPadKontrolEvent *)event;

- (void)button:(uint8_t)button wasPressed:(PSPadKontrolEvent *)event;
- (void)buttonReleased:(PSPadKontrolEvent *)event;

- (void)knobTurned:(PSPadKontrolEvent *)event value:(uint8_t)value;
- (void)encoderTurned:(PSPadKontrolEvent *)event direction:(uint8_t)direction;

- (void)xyPadPressed;
- (void)xyPadReleased;

- (void)xyPadMoved:(PSPadKontrolEvent *)event x:(uint8_t)x y:(uint8_t)y;
@end
