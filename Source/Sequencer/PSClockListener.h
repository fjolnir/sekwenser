//
//  PSClockListener.h
//  sekwenser
//
//  Created by フィヨ on 10/10/11.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PSClock;

@protocol PSClockListener
- (void)clockPulseHappened:(PSClock *)clock;
- (void)clockDidStop:(PSClock *)clock;
- (void)clockDidStart:(PSClock *)clock;
@end
