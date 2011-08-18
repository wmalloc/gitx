//
//  PBGitHistoryController.h
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "PBGitCommit.h"
#import "PBGitTree.h"
#import "PBViewController.h"

@class PBGitSidebarController;
@class PBWebHistoryController;
@class PBGitGradientBarView;
@class PBRefController;
@class QLPreviewPanel;
@class PBCommitList;
@class GLFileView;
@class PBHistorySearchController;

// Controls the split history view from PBGitHistoryView.xib
@interface PBGitHistoryController : PBViewController PROTOCOL_10_6(NSOutlineViewDelegate, QLPreviewPanelDelegate, QLPreviewPanelDataSource)
{
	IBOutlet PBRefController *refController;
	IBOutlet NSSearchField *searchField;
	IBOutlet NSArrayController* commitController;
	IBOutlet NSSearchField *filesSearchField;
	IBOutlet NSTreeController* treeController;
	IBOutlet NSOutlineView* fileBrowser;
	NSArray *currentFileBrowserSelectionPath;
	IBOutlet PBCommitList* commitList;
	IBOutlet NSSplitView *historySplitView;
	IBOutlet PBWebHistoryController *webHistoryController;
	QLPreviewPanel* previewPanel;
	IBOutlet PBHistorySearchController *searchController;
	IBOutlet GLFileView *fileView;

	IBOutlet PBGitGradientBarView *upperToolbarView;
	IBOutlet NSButton *mergeButton;
	IBOutlet NSButton *cherryPickButton;
	IBOutlet NSButton *rebaseButton;

	IBOutlet PBGitGradientBarView *scopeBarView;
	IBOutlet NSButton *allBranchesFilterItem;
	IBOutlet NSButton *localRemoteBranchesFilterItem;
	IBOutlet NSButton *selectedBranchFilterItem;

	IBOutlet id webView;
	int selectedCommitDetailsIndex;
	BOOL forceSelectionUpdate;
	
	PBGitTree *gitTree;
	PBGitCommit *webCommit;
	PBGitCommit *selectedCommit;
	PBGitCommit *selectedCommitBeforeRefresh;
}

@property (readonly) NSTreeController* treeController;
@property (readonly) NSSplitView *historySplitView;
@property (assign) int selectedCommitDetailsIndex;
@property (retain) PBGitCommit *webCommit;
@property (retain) PBGitTree* gitTree;
@property (readonly) NSArrayController *commitController;
@property (readonly) PBRefController *refController;
@property (readonly) PBHistorySearchController *searchController;
@property (readonly) PBCommitList *commitList;

- (IBAction) setDetailedView:(id)sender;
- (IBAction) setTreeView:(id)sender;
- (IBAction) setBranchFilter:(id)sender;

- (void)selectCommit:(NSString *)commit;
- (IBAction) refresh:(id)sender;
- (IBAction) toggleQLPreviewPanel:(id)sender;
- (IBAction) openSelectedFile:(id)sender;
- (void) updateQuicklookForce: (BOOL) force;

// Context menu methods
- (NSMenu *)contextMenuForTreeView;
- (NSArray *)menuItemsForPaths:(NSArray *)paths;
- (void)showCommitsFromTree:(id)sender;
- (void)showInFinderAction:(id)sender;
- (void)openFilesAction:(id)sender;

// Repository Methods
- (IBAction) createBranch:(id)sender;
- (IBAction) createTag:(id)sender;
- (IBAction) showAddRemoteSheet:(id)sender;
- (IBAction) merge:(id)sender;
- (IBAction) cherryPick:(id)sender;
- (IBAction) rebase:(id)sender;

// Find/Search methods
- (IBAction)selectNext:(id)sender;
- (IBAction)selectPrevious:(id)sender;
- (IBAction) updateSearch:(id) sender;

- (void) copyCommitInfo;
- (void) copyCommitSHA;

- (BOOL) hasNonlinearPath;

- (NSMenu *)tableColumnMenu;

- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview;
- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex;

@property (retain) NSSearchField *searchField;
@property (retain) NSSearchField *filesSearchField;
@property (retain) NSOutlineView* fileBrowser;
@property (retain) NSArray *currentFileBrowserSelectionPath;
@property (retain) PBWebHistoryController *webHistoryController;
@property (retain) QLPreviewPanel* previewPanel;
@property (retain) GLFileView *fileView;
@property (retain) PBGitGradientBarView *upperToolbarView;
@property (retain) NSButton *mergeButton;
@property (retain) NSButton *cherryPickButton;
@property (retain) NSButton *rebaseButton;
@property (retain) PBGitGradientBarView *scopeBarView;
@property (retain) NSButton *allBranchesFilterItem;
@property (retain) NSButton *localRemoteBranchesFilterItem;
@property (retain) NSButton *selectedBranchFilterItem;
@property (retain) id webView;
@property BOOL forceSelectionUpdate;
@property (retain) PBGitCommit *selectedCommit;
@property (retain) PBGitCommit *selectedCommitBeforeRefresh;
@end
