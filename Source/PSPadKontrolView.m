//
//  PSPadKontrolView.m
//  Sekwenser
//
//  Created by フィヨ on 10/10/30.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PSPadKontrolView.h"
#import "PSPadKontrol.h"
#import "PSPadKontrolEvent.h"

static PSPadKontrolView *_KeyView;

@implementation PSPadKontrolView
- (BOOL)isKey {
    return _KeyView == self;
}
- (void)makeKey {
    [_KeyView resignKey];
    [[[PSPadKontrol sharedPadKontrol] eventListeners] addObject:self];
    _KeyView = self;
    [self updateLights];
}
- (void)resignKey {
   [[[PSPadKontrol sharedPadKontrol] eventListeners] removeObject:self];
   _KeyView = nil;
}

- (id)init
{
    if(!(self = [super init]))
        return nil;
    
    return self;
}

- (BOOL)padKontrolEventReceived:(PSPadKontrolEvent *)event
                 fromPadKontrol:(PSPadKontrol *)padKontrol {
    switch ([event type]) {
        case PSPadKontrolEnteredNativeMode:
            [self padKontrolReady];
        case PSPadKontrolPadPressEventType:
            [self padPressed:event];
            break;
        case PSPadKontrolPadReleaseEventType:
            [self padReleased:event];
            break;
        case PSPadKontrolButtonPressEventType:
            [self button:event.affected_entity_code wasPressed:event];
            break;
        case PSPadKontrolButtonReleaseEventType:
            [self buttonReleased:event];
            break;
        case PSPadKontrolEncoderTurnEventType:
            [self encoderTurned:event direction:*event.values];
            break;
        case PSPadKontrolKnobTurnEventType:
            [self knobTurned:event value:*event.values];
            break;
        case PSPadKontrolXYPadPressEventType:
            [self xyPadPressed];
            break;
        case PSPadKontrolXYPadReleaseEventType:
            [self xyPadReleased];
            break;
        case PSPadKontrolXYPadMoveEventType:
            [self xyPadMoved:event x:*event.values y:*(event.values+1)];
            break;
        default:
            break;
    }
    return YES;
}

#pragma mark -
- (void)padKontrolReady {
	// Functionality implemented in subclasses
}

#pragma mark -
- (void)updateLights {
	// Functionality implemented in subclasses
}

#pragma mark -
- (void)padPressed:(PSPadKontrolEvent *)event {
	// Functionality implemented in subclasses
}
- (void)padReleased:(PSPadKontrolEvent *)event {
	// Functionality implemented in subclasses
}

- (void)button:(uint8_t)button wasPressed:(PSPadKontrolEvent *)event {
	// Functionality implemented in subclasses
}
- (void)buttonReleased:(PSPadKontrolEvent *)event {
	// Functionality implemented in subclasses
}

- (void)knobTurned:(PSPadKontrolEvent *)event value:(uint8_t)value {
	// Functionality implemented in subclasses
}
- (void)encoderTurned:(PSPadKontrolEvent *)event direction:(uint8_t)direction {
	// Functionality implemented in subclasses
}

- (void)xyPadPressed {
	// Functionality implemented in subclasses
}
- (void)xyPadReleased {
	// Functionality implemented in subclasses
}

- (void)xyPadMoved:(PSPadKontrolEvent *)event x:(uint8_t)x y:(uint8_t)y {
	// Functionality implemented in subclasses
}
@end
