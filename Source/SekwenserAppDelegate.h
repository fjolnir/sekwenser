//
//  SekwenserAppDelegate.h
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PSPadKontrol;

@interface SekwenserAppDelegate : NSObject <NSApplicationDelegate, NSTableViewDataSource> {
	NSWindow *window;
	
	IBOutlet NSPopUpButton *syncSourcePopupBtn;
	
	NSMutableArray *savedLayouts;
	IBOutlet NSTableView *layoutListTable;
	
}

@property(assign) IBOutlet NSWindow *window;
@property(assign) IBOutlet NSTableView *layoutListTable;
@property(readwrite, retain) NSMutableArray *savedLayouts;

- (IBAction)refreshMidiSources:(id)sender;
- (IBAction)selectSyncSource:(id)sender;
- (IBAction)showOpenWindow:(id)sender;
- (IBAction)loadSelected:(id)sender;
- (void)performLoad:(NSString *)path;
- (IBAction)performSave:(id)sender;
- (IBAction)performSaveWithoutDialog:(id)sender;
- (IBAction)performDelete:(id)sender;

- (void)updateLayoutList;
@end
