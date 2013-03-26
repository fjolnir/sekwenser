////////////////////////////////////////////////////////////////////////////////////////////
//
//  SekwenserAppDelegate
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


#import "SekwenserAppDelegate.h"
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSECombinationOutputStream.h"
#import "PadKontrolConstants.h"
#import "PSClock.h"
#import "PSPadKontrolEvent.h"

#import "PSSequencer.h"
#import "PSPadKontrol.h"

#define LAYOUT_DIR_PATH [@"~/Documents/sekwenser layouts" stringByExpandingTildeInPath]

@implementation SekwenserAppDelegate
@synthesize window=_window, savedLayouts=_savedLayouts, layoutListTable=_layoutListTable;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
	// Initialize midi before the app finishes launching
	if([SMClient sharedClient] == nil) {
		NSRunAlertPanel(NSLocalizedString(@"MIDIinitFailTitle", @"Couldn't initialize MIDI"),
										NSLocalizedString(@"MIDIinitFailDescription", @"There was an error while trying to initialize the CoreMIDI subsystem")
																			, @"Quit", nil, nil);
		[NSApp terminate:nil];
	}
	// Initialize the clock
	PSClock *clock = [PSClock globalClock];
	//[clock setSyncMode:kCAClockSyncMode_Internal];
	//[clock start];
	[clock arm];

    [[[PSPadKontrol sharedPadKontrol] eventListeners] addObject:self];
	// Initialize the sequencer
	[[PSPadKontrol sharedPadKontrol] enterNativeMode];
    _sequencer = [PSSequencer new];
	[_sequencer makeKey];

	[self updateLayoutList];
	[self refreshMidiSources:nil];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[_window orderFront:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	[[PSPadKontrol sharedPadKontrol] exitNativeMode];
}

- (void)dealloc {
  [_savedLayouts release];
  
  [super dealloc];
}

// Mode selektor
- (BOOL)padKontrolEventReceived:(PSPadKontrolEvent *)event fromPadKontrol:(PSPadKontrol *)padKontrol {
    if(event.type == PSPadKontrolButtonReleaseEventType && event.affected_entity_code == kSettingBtn_code) {
        if([_sequencer isKey]) {
            [_sequencer resignKey];
            [[PSPadKontrol sharedPadKontrol] resetAllLights];
        } else {
            [_sequencer makeKey];
        }
        return NO;
    }
    return YES;
}

// Interface stuff
- (IBAction)refreshMidiSources:(id)sender {
	OSErr err;
	
	[_syncSourcePopupBtn removeAllItems];
	unsigned numberOfSources = MIDIGetNumberOfSources();
	if(numberOfSources == 0) {
		[_syncSourcePopupBtn addItemWithTitle:@"No MIDI Inputs found"];
		return;
	}
	MIDIEndpointRef currPoint;
	CFStringRef srcDisplayName;
	for(int i = 0; i < numberOfSources; ++i) {
		currPoint = MIDIGetSource(i);
		err = MIDIObjectGetStringProperty(currPoint, kMIDIPropertyDisplayName, &srcDisplayName);
		if (err) 
			NSLog(@"MIDI Get sourceName err = %d", err);
		
		[_syncSourcePopupBtn addItemWithTitle:(NSString *)srcDisplayName];
		if([(NSString *)srcDisplayName isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"MIDISyncSource"]]) {
			[_syncSourcePopupBtn selectItemAtIndex:i];
			[[PSClock globalClock] setMIDISyncSource:(NSString *)srcDisplayName];
		}
		CFRelease(srcDisplayName);
	}
	
}
- (IBAction)selectSyncSource:(id)sender {
	NSString *sourceName = [_syncSourcePopupBtn titleOfSelectedItem];
	[[PSClock globalClock] setMIDISyncSource:sourceName];
	[[NSUserDefaults standardUserDefaults] setObject:sourceName forKey:@"MIDISyncSource"];
}
- (IBAction)showOpenWindow:(id)sender {
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"seklayout"]];
	[openPanel beginSheetModalForWindow:_window completionHandler:^(NSInteger result){
		if(result == NSFileHandlingPanelOKButton)
			[self performLoad:[[[openPanel URLs] objectAtIndex:0] path]];
	}];
}

- (IBAction)loadSelected:(id)sender {
    if([_layoutListTable selectedRow] == -1)
        return;
	NSString *path = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[_savedLayouts objectAtIndex:[_layoutListTable selectedRow]]];
	[self performLoad:path];
}

- (void)performLoad:(NSString *)path {
	NSMutableArray *loadedSets;
	NSMutableArray *loadedPatternSeqSteps;
	NSDictionary *loadedData = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
	
	loadedSets = [loadedData objectForKey:@"patternSets"];
	loadedPatternSeqSteps = [loadedData objectForKey:@"patternSetSequencerSteps"];
	
	[_sequencer resetSequencer];
	[_sequencer setPatternSets:loadedSets];
	[_sequencer setPatternSetSequencerSteps:loadedPatternSeqSteps];
	[_sequencer setActivePatternSet:[loadedSets objectAtIndex:0]];
	[_sequencer updateLights];
}
- (void)saveToPath:(NSString *)path {
	NSDictionary *forSaving = [NSDictionary dictionaryWithObjectsAndKeys:
														 [_sequencer patternSets], @"patternSets",
														 _sequencer.patternSetSequencerSteps, @"patternSetSequencerSteps", nil];
	BOOL success = [NSKeyedArchiver archiveRootObject:forSaving
																						 toFile:path];
	if(!success)
		NSRunAlertPanel(NSLocalizedString(@"saveErrorTitle", @"Save Error"), NSLocalizedString(@"saveErrorDescription", @"There was an error while trying to build the layout file for saving."), NSLocalizedString(@"love", @"Fuck!"), nil, nil);
	
}
- (IBAction)performSave:(id)sender {
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"seklayout"]];
	[savePanel beginSheetModalForWindow:_window completionHandler:^(NSInteger result){
		if(result == NSFileHandlingPanelOKButton)
			[self saveToPath:[[savePanel URL] path]];
	}];
}
- (IBAction)performSaveWithoutDialog:(id)sender {
	if(![[NSFileManager defaultManager] createDirectoryAtPath:LAYOUT_DIR_PATH
														withIntermediateDirectories:YES
																						 attributes:nil error:nil]) {
		NSLog(@"Couldn't create layout directory");
		return;
	}
	NSUInteger fileNumber = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:LAYOUT_DIR_PATH error:nil] count] + 1;
	NSString *destPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[NSString stringWithFormat:@"Layout %d.seklayout", fileNumber]];
	[self saveToPath:destPath];

	[self updateLayoutList];
}

- (IBAction)performDelete:(id)sender {
    if([_layoutListTable selectedRow] == -1)
        return;
	NSString *trashDir = [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"];
	
	[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
																							 source:LAYOUT_DIR_PATH
																					destination:trashDir
																								files:[_savedLayouts objectsAtIndexes:[NSIndexSet indexSetWithIndex:[_layoutListTable selectedRow]]] 
																									tag:NULL];
	[self updateLayoutList];
}

- (void)updateLayoutList {
	self.savedLayouts = [NSMutableArray array];
	NSArray *filenames;
	if(!(filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:LAYOUT_DIR_PATH error:nil]))
		return;
	// else
	[_savedLayouts addObjectsFromArray:filenames];
	// Sort
	[_savedLayouts sortUsingComparator:^(id a, id b)
	 {
		 NSString *aPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:a];
		 NSString *bPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:b];
		 NSDictionary *aAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:aPath error:nil];
		 NSDictionary *bAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:bPath error:nil];
		 
		 return [[aAttrs objectForKey:NSFileModificationDate] compare:[bAttrs objectForKey:NSFileModificationDate]];
	 }];
	[_layoutListTable reloadData];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
	[self performLoad:filename];
	return YES;
}

#pragma mark -
// Layout table datasource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
	if(_savedLayouts)
		return [_savedLayouts count];
	return 0;
}
- (id)tableView:(NSTableView *)aTableView 
objectValueForTableColumn:(NSTableColumn *)column
						row:(NSInteger)rowIndex {
	if([[column identifier] isEqualToString:@"title"])
		return [[_savedLayouts objectAtIndex:rowIndex] stringByDeletingPathExtension];
	else if([[column identifier] isEqualToString:@"creationDate"]) {
		NSString *path = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[_savedLayouts objectAtIndex:rowIndex]];
		NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
		if(attrs)
			return [attrs objectForKey:NSFileModificationDate];
	}
	return nil;
}
- (void)tableView:(NSTableView *)aTableView
	 setObjectValue:(id)newValue
	 forTableColumn:(NSTableColumn *)aTableColumn
							row:(NSInteger)rowIndex {
	NSString *origPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[_savedLayouts objectAtIndex:rowIndex]];
	NSString *destPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[newValue stringByAppendingPathExtension:@"seklayout"]];
	[[NSFileManager defaultManager] moveItemAtPath:origPath toPath:destPath error:nil];
	[self updateLayoutList];
}
@end
