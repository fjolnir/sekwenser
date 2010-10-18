/*
 *  PSPadKontrolEventListener.h
 *  sekwenser
 *
 *  Created by フィヨ on 10/10/11.
 *  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
 *
 */

@class PSPadKontrol;
@class PSPadKontrolEvent;

@protocol PSPadKontrolEventListener
- (void)padKontrolEventReceived:(PSPadKontrolEvent *)event fromPadKontrol:(PSPadKontrol *)padKontrol;
@end