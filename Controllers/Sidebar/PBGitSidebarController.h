//
//  PBGitSidebar.h
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"

@class PBSourceViewItem;
@class PBGitHistoryController;
@class PBGitCommitController;
@class PBStashContentController;

@interface PBGitSidebarController : PBViewController PROTOCOL_10_6(NSOutlineViewDelegate, NSMenuDelegate)
{
	IBOutlet NSWindow *window;
	IBOutlet NSOutlineView *sourceView;
	IBOutlet NSView *sourceListControlsView;
	IBOutlet NSPopUpButton *actionButton;
	IBOutlet NSSegmentedControl *remoteControls;

	IBOutlet NSButton* svnFetchButton;
	IBOutlet NSButton* svnRebaseButton;
	IBOutlet NSButton* svnDcommitButton;
    
	NSMutableArray *items;

	/* Specific things */
	PBSourceViewItem *stage;

	PBSourceViewItem *branches, *remotes, *tags, *others, *stashes, *submodules;

	PBGitHistoryController *historyViewController;
	PBGitCommitController *commitViewController;
	PBStashContentController *stashViewController;
}

- (void) selectStage;
- (void) selectCurrentBranch;

- (NSMenu *) menuForRow:(NSInteger)row;

- (IBAction) fetchPullPushAction:(id)sender;
- (IBAction) svnFetch:(id)sender;
- (IBAction) svnRebase:(id)sender;
- (IBAction) svnDcommit:(id)sender;

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode;

-(NSNumber *)countCommintsOf:(NSString *)range;
-(bool)remoteNeedFetch:(NSString *)remote;

@property(readonly) NSMutableArray *items;
@property(readonly) NSView *sourceListControlsView;
@property(readonly) PBGitHistoryController *historyViewController;
@property(readonly) PBGitCommitController *commitViewController;
@property(readonly) PBStashContentController *stashViewController;

@property (retain) NSWindow *window;
@property (retain) NSOutlineView *sourceView;
@property (retain) NSPopUpButton *actionButton;
@property (retain) NSSegmentedControl *remoteControls;
@property (retain) NSButton* svnFetchButton;
@property (retain) NSButton* svnRebaseButton;
@property (retain) NSButton* svnDcommitButton;
@property (retain) PBSourceViewItem *stage;
@end
