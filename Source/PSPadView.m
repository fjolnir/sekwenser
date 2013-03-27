#import "PSPadView.h"
#import "PSPadKontrolEvent.h"
#import "SekwenserAppDelegate.h"
#import "PadkontrolConstants.h"
#import <SnoizeMIDI/SnoizeMIDI.h>

@implementation PSPadView
@synthesize activeBank=_activeBank, fixedVelocity=_fixedVelocity;

- (void)padPressed:(PSPadKontrolEvent *)event
{
    if(!_inBankSelection) {
        uint8_t velocity = _fixedVelocity ? 127 : event.velocity;
        TransmitCC(event.affectedPad, _activeBank+6, velocity);
        [[PSPadKontrol sharedPadKontrol] controlLight:kPadOn_codes + event.affectedPad
                                                state:&kPad_lightOn_code];
        [[PSPadKontrol sharedPadKontrol] setLEDNumber:velocity blink:NO];
    } else {
        [[PSPadKontrol sharedPadKontrol] controlLight:kPadOn_codes + _activeBank
                                                state:&kPad_lightOff_code];
        _activeBank = event.affectedPad;
        [self updateLights];
    }
}

- (void)padReleased:(PSPadKontrolEvent *)event
{
    if(_inBankSelection)
        return;
    TransmitCC(event.affectedPad, _activeBank+6, 0);
    [[PSPadKontrol sharedPadKontrol] controlLight:kPadOn_codes + event.affectedPad
                                            state:&kPad_lightOff_code];
}

- (void)button:(uint8_t)button wasPressed:(PSPadKontrolEvent *)event
{
    if(button == kSceneBtn_code) {
        _inBankSelection = YES;
        [self updateLights];
    }
}

- (void)button:(uint8_t)button wasReleased:(PSPadKontrolEvent *)event
{
    if(button == kFixedVelBtn_code) {
        _fixedVelocity = !_fixedVelocity;
        [self updateLights];
    } else if(button == kSceneBtn_code) {
        _inBankSelection = NO;
        [self updateLights];
    }
}

- (void)didBecomeKey
{
    [[PSPadKontrol sharedPadKontrol] setLEDString:"PAD" blink:NO];
}

- (void)updateLights
{
    [[PSPadKontrol sharedPadKontrol] controlLight:&kFixedVelBtn_code
                                            state:_fixedVelocity
                                                  ? &kPad_lightOn_code
                                                  : &kPad_lightOff_code];

    if(_inBankSelection) {
        [[PSPadKontrol sharedPadKontrol] controlLight:kPadOn_codes + _activeBank
                                                state:&kPad_lightOn_code];
    } else {
        [[PSPadKontrol sharedPadKontrol] controlLight:kPadOn_codes + _activeBank
                                                state:&kPad_lightOff_code];

    }
}

@end
