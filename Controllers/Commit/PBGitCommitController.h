//
//  PBGitCommitController.h
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"

@class PBGitIndexController, PBIconAndTextCell, PBWebChangesController, PBGitIndex;

@interface PBGitCommitController : PBViewController {
	// This might have to transfer over to the PBGitRepository
	// object sometime
	PBGitIndex *index;
	
	IBOutlet NSTextView *commitMessageView;
	IBOutlet NSArrayController *unstagedFilesController;
	IBOutlet NSArrayController *cachedFilesController;
	IBOutlet NSButton *commitButton;

	IBOutlet PBGitIndexController *indexController;
	IBOutlet PBWebChangesController *webController;
	IBOutlet NSSplitView *commitSplitView;
}

@property(readonly) PBGitIndex *index;

- (IBAction) refresh:(id) sender;
- (IBAction) commit:(id) sender;
- (IBAction) forceCommit:(id) sender;
- (IBAction)signOff:(id)sender;
@property (retain) NSTextView *commitMessageView;
@property (retain) NSArrayController *unstagedFilesController;
@property (retain) NSArrayController *cachedFilesController;
@property (retain) NSButton *commitButton;
@property (retain) PBGitIndexController *indexController;
@property (retain) PBWebChangesController *webController;
@property (retain) NSSplitView *commitSplitView;
@end
