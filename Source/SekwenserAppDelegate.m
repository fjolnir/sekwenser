//
//  SekwenserAppDelegate.m
//  sekwenser
//
//  Created by フィヨ on 10/10/09.
//  Copyright 2010 Fjölnir Ásgeirsson. All rights reserved.
//

#import "SekwenserAppDelegate.h"
#import <SnoizeMIDI/SnoizeMIDI.h>
#import "SSECombinationOutputStream.h"
#import "PadKontrolConstants.h"
#import "PSClock.h"

#import "PSSequencer.h"
#import "PSPadKontrol.h"

#define LAYOUT_DIR_PATH [@"~/Documents/sekwenser layouts" stringByExpandingTildeInPath]

@implementation SekwenserAppDelegate
@synthesize window, savedLayouts, layoutListTable;

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	// Initialize midi before the app finishes launching
	if([SMClient sharedClient] == nil)
	{
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
	
	// Initialize the sequencer
	[[PSPadKontrol sharedPadKontrol] enterNativeMode];
	[PSSequencer sharedSequencer];

	[self updateLayoutList];
	[self refreshMidiSources:nil];
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[self.window orderFront:nil];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[[PSPadKontrol sharedPadKontrol] exitNativeMode];
}

// Interface stuff
- (IBAction)refreshMidiSources:(id)sender
{
	OSErr err;
	
	[syncSourcePopupBtn removeAllItems];
	unsigned numberOfSources = MIDIGetNumberOfSources();
	if(numberOfSources == 0)
	{
		[syncSourcePopupBtn addItemWithTitle:@"No MIDI Inputs found"];
		return;
	}
	MIDIEndpointRef currPoint;
	CFStringRef srcDisplayName;
	for(int i = 0; i < numberOfSources; ++i)
	{
		currPoint = MIDIGetSource(i);
		err = MIDIObjectGetStringProperty(currPoint, kMIDIPropertyDisplayName, &srcDisplayName);
		if (err) 
			NSLog(@"MIDI Get sourceName err = %d", err);
		
		[syncSourcePopupBtn addItemWithTitle:(NSString *)srcDisplayName];
		if([(NSString *)srcDisplayName isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"MIDISyncSource"]])
		{
			[syncSourcePopupBtn selectItemAtIndex:i];
			[[PSClock globalClock] setMIDISyncSource:(NSString *)srcDisplayName];
		}
		CFRelease(srcDisplayName);
	}
	
}
- (IBAction)selectSyncSource:(id)sender
{
	NSString *sourceName = [syncSourcePopupBtn titleOfSelectedItem];
	[[PSClock globalClock] setMIDISyncSource:sourceName];
	[[NSUserDefaults standardUserDefaults] setObject:sourceName forKey:@"MIDISyncSource"];
}
- (IBAction)showOpenWindow:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObject:@"seklayout"]];
	[openPanel beginSheetModalForWindow:window completionHandler:^(NSInteger result){
		if(result == NSFileHandlingPanelOKButton)
			[self performLoad:[[[openPanel URLs] objectAtIndex:0] path]];
	}];
}

- (IBAction)loadSelected:(id)sender
{
	NSString *path = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[self.savedLayouts objectAtIndex:[self.layoutListTable selectedRow]]];
	[self performLoad:path];
}

- (void)performLoad:(NSString *)path
{
	NSMutableArray *loadedSets;
	loadedSets = [NSKeyedUnarchiver unarchiveObjectWithFile:path];
	
	[[PSSequencer sharedSequencer] resetSequencer];
	[[PSSequencer sharedSequencer] setPatternSets:loadedSets];
	[[PSSequencer sharedSequencer] setActivePatternSet:[loadedSets objectAtIndex:0]];
	[[PSSequencer sharedSequencer] updateLights];
}
- (IBAction)performSave:(id)sender
{
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"seklayout"]];
	[savePanel beginSheetModalForWindow:window completionHandler:^(NSInteger result){
		if(result == NSFileHandlingPanelOKButton)
		{
			BOOL success = [NSKeyedArchiver archiveRootObject:[[PSSequencer sharedSequencer] patternSets]
																								 toFile:[[savePanel URL] path]];
			if(!success)
				NSRunAlertPanel(NSLocalizedString(@"saveErrorTitle", @"Save Error"), NSLocalizedString(@"saveErrorDescription", @"There was an error while trying to build the layout file for saving."), NSLocalizedString(@"love", @"Fuck!"), nil, nil);
		}
	}];
}
- (IBAction)performSaveWithoutDialog:(id)sender
{
	if(![[NSFileManager defaultManager] createDirectoryAtPath:LAYOUT_DIR_PATH
														withIntermediateDirectories:YES
																						 attributes:nil error:nil])
	{
		NSLog(@"Couldn't create layout directory");
		return;
	}
	NSString *destPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[[[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil] stringByAppendingPathExtension:@"seklayout"]];
	[NSKeyedArchiver archiveRootObject:[[PSSequencer sharedSequencer] patternSets]
															toFile:destPath];
	[self updateLayoutList];
}
- (IBAction)performDelete:(id)sender
{
	NSString *trashDir = [NSHomeDirectory() stringByAppendingPathComponent:@".Trash"];
	
	[[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
																							 source:LAYOUT_DIR_PATH
																					destination:trashDir
																								files:[self.savedLayouts objectsAtIndexes:[NSIndexSet indexSetWithIndex:[self.layoutListTable selectedRow]]] 
																									tag:NULL];
	[self updateLayoutList];
}

- (void)updateLayoutList
{
	self.savedLayouts = [NSMutableArray array];
	NSArray *filenames;
	if(!(filenames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:LAYOUT_DIR_PATH error:nil]))
		return;
	// else
	[self.savedLayouts addObjectsFromArray:filenames];
	// Sort
	[self.savedLayouts sortUsingComparator:^(id a, id b)
	 {
		 NSString *aPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:a];
		 NSString *bPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:b];
		 NSDictionary *aAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:aPath error:nil];
		 NSDictionary *bAttrs = [[NSFileManager defaultManager] attributesOfItemAtPath:bPath error:nil];
		 
		 return [[aAttrs objectForKey:NSFileModificationDate] compare:[bAttrs objectForKey:NSFileModificationDate]];
	 }];
	[self.layoutListTable reloadData];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
	[self performLoad:filename];
	return YES;
}

#pragma mark -
// Layout table datasource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if(self.savedLayouts)
		return [self.savedLayouts count];
	return 0;
}
- (id)tableView:(NSTableView *)aTableView 
objectValueForTableColumn:(NSTableColumn *)column
						row:(NSInteger)rowIndex
{
	if([[column identifier] isEqualToString:@"title"])
		return [[self.savedLayouts objectAtIndex:rowIndex] stringByDeletingPathExtension];
	else if([[column identifier] isEqualToString:@"creationDate"])
	{
		NSString *path = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[self.savedLayouts objectAtIndex:rowIndex]];
		NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
		if(attrs)
			return [attrs objectForKey:NSFileModificationDate];
	}
	return nil;
}
- (void)tableView:(NSTableView *)aTableView
	 setObjectValue:(id)newValue
	 forTableColumn:(NSTableColumn *)aTableColumn
							row:(NSInteger)rowIndex
{
	NSString *origPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[self.savedLayouts objectAtIndex:rowIndex]];
	NSString *destPath = [LAYOUT_DIR_PATH stringByAppendingPathComponent:[newValue stringByAppendingPathExtension:@"seklayout"]];
	[[NSFileManager defaultManager] moveItemAtPath:origPath toPath:destPath error:nil];
	[self updateLayoutList];
}
@end
