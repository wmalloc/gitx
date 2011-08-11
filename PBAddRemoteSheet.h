//
//  PBAddRemoteSheet.h
//  GitX
//
//  Created by Nathan Kinsinger on 12/8/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class PBGitRepository;

@interface PBAddRemoteSheet : NSWindowController
{
	PBGitRepository *repository;

	NSTextField *remoteNameTextField;
	NSTextField *remoteURLTextField;
	NSTextField *errorMessageTextField;

	NSOpenPanel *browseSheetOpenPanel;
	NSView      *browseAccessoryView;
}

+ (void) beginAddRemoteSheetForRepository:(PBGitRepository *)repo;

- (IBAction) browseFolders:(id)sender;
- (IBAction) addRemote:(id)sender;
- (IBAction) orderOutAddRemoteSheet:(id)sender;
- (IBAction) showHideHiddenFiles:(id)sender;


@property (readwrite) PBGitRepository *repository;

@property (readwrite) IBOutlet NSTextField *remoteNameTextField;
@property (readwrite) IBOutlet NSTextField *remoteURLTextField;
@property (readwrite) IBOutlet NSTextField *errorMessageTextField;

@property (readwrite)          NSOpenPanel *browseSheetOpenPanel;
@property (readwrite) IBOutlet NSView      *browseAccessoryView;

@end
