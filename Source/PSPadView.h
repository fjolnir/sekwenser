#import "PSPadKontrolView.h"

@interface PSPadView : PSPadKontrolView {
    NSUInteger _activeBank;
    BOOL _fixedVelocity;
    BOOL _inBankSelection;
}
@property(readwrite) NSUInteger activeBank;
@property(readwrite) BOOL fixedVelocity;

@end
