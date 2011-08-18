//
//  PBDetailController.h
//  GitX
//
//  Created by Pieter de Bie on 16-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRepository.h"

#define kGitSplitViewMinWidth 150.0f
#define kGitSplitViewMaxWidth 300.0f

@class PBViewController, PBGitSidebarController, PBGitCommitController;

// Controls the main repository window from RepositoryWindow.xib
@interface PBGitWindowController : NSWindowController PROTOCOL_10_6(NSWindowDelegate){
	__weak PBGitRepository* repository;

	PBViewController *contentController;

	PBGitSidebarController *sidebarController;
	IBOutlet NSView *sourceListControlsView;
	IBOutlet NSSplitView *mainSplitView;
	IBOutlet NSView *sourceSplitView;
	IBOutlet NSView *contentSplitView;

	IBOutlet NSTextField *statusField;
	IBOutlet NSProgressIndicator *progressIndicator;

	IBOutlet NSToolbarItem *terminalItem;
	IBOutlet NSToolbarItem *finderItem;
    
    NSArray *splitViews;
    NSMutableArray *splitViewsSize;
}

@property (assign) __weak PBGitRepository *repository;

- (id)initWithRepository:(PBGitRepository*)theRepository displayDefault:(BOOL)display;

- (void)changeContentController:(PBViewController *)controller;

- (void)showCommitHookFailedSheet:(NSString *)messageText infoText:(NSString *)infoText commitController:(PBGitCommitController *)controller;
- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText;
- (void)showErrorSheet:(NSError *)error;
- (void)showErrorSheetTitle:(NSString *)title message:(NSString *)message arguments:(NSArray *)arguments output:(NSString *)output;

-(void)initChangeLayout;
-(IBAction)changeLayout:(id)sender;

- (IBAction) showCommitView:(id)sender;
- (IBAction) showHistoryView:(id)sender;
- (IBAction) revealInFinder:(id)sender;
- (IBAction) openInTerminal:(id)sender;
- (IBAction) cloneTo:(id)sender;
- (IBAction) refresh:(id)sender;

- (void)selectCommitForSha:(NSString *)sha;
- (NSArray *)menuItemsForPaths:(NSArray *)paths;
- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode;

@property (retain) PBViewController *contentController;
@property (retain) PBGitSidebarController *sidebarController;
@property (retain) NSView *sourceListControlsView;
@property (retain) NSSplitView *mainSplitView;
@property (retain) NSView *sourceSplitView;
@property (retain) NSView *contentSplitView;
@property (retain) NSTextField *statusField;
@property (retain) NSProgressIndicator *progressIndicator;
@property (retain) NSToolbarItem *terminalItem;
@property (retain) NSToolbarItem *finderItem;
@property (retain) NSArray *splitViews;
@property (retain) NSMutableArray *splitViewsSize;
@end
