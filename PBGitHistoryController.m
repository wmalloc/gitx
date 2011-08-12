//
//  PBGitHistoryController.m
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitHistoryController.h"
#import "PBWebHistoryController.h"
#import "PBGitGrapher.h"
#import "PBGitRevisionCell.h"
#import "PBCommitList.h"
#import "PBCreateBranchSheet.h"
#import "PBCreateTagSheet.h"
#import "PBAddRemoteSheet.h"
#import "PBGitSidebarController.h"
#import "PBGitGradientBarView.h"
#import "PBDiffWindowController.h"
#import "PBGitDefaults.h"
#import "PBGitRevList.h"
#import "PBHistorySearchController.h"
#import "PBQLTextView.h"
#import "GLFileView.h"

#import "PBSourceViewCell.h"

#define kHistorySelectedDetailIndexKey @"PBHistorySelectedDetailIndex"
#define kHistoryDetailViewIndex 0
#define kHistoryTreeViewIndex 1

#define kHistorySplitViewPositionDefault @"History SplitView Position"

@interface PBGitHistoryController ()

- (void) updateBranchFilterMatrix;
- (void) restoreFileBrowserSelection;
- (void) saveFileBrowserSelection;
- (void)saveSplitViewPosition;

@end


@implementation PBGitHistoryController
@synthesize selectedCommitDetailsIndex, webCommit, gitTree, commitController, refController;
@synthesize searchController;
@synthesize commitList;
@synthesize treeController;
@synthesize historySplitView;

- (void)awakeFromNib
{
	self.selectedCommitDetailsIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kHistorySelectedDetailIndexKey];

	[commitController addObserver:self forKeyPath:@"selection" options:0 context:@"commitChange"];
	[commitController addObserver:self forKeyPath:@"arrangedObjects.@count" options:NSKeyValueObservingOptionInitial context:@"updateCommitCount"];
	[treeController addObserver:self forKeyPath:@"selection" options:0 context:@"treeChange"];

	[repository.revisionList addObserver:self forKeyPath:@"isUpdating" options:0 context:@"revisionListUpdating"];
	[repository addObserver:self forKeyPath:@"currentBranch" options:0 context:@"branchChange"];
	[repository addObserver:self forKeyPath:@"refs" options:0 context:@"updateRefs"];
	[repository addObserver:self forKeyPath:@"currentBranchFilter" options:0 context:@"branchFilterChange"];

	forceSelectionUpdate = YES;
	NSSize cellSpacing = [commitList intercellSpacing];
	cellSpacing.height = 0;
	[commitList setIntercellSpacing:cellSpacing];
	[fileBrowser setTarget:self];
	[fileBrowser setDoubleAction:@selector(openSelectedFile:)];

	if (!repository.currentBranch) {
		[repository reloadRefs];
		[repository readCurrentBranch];
	}
	else
		[repository lazyReload];

	// Set a sort descriptor for the subject column in the history list, as
	// It can't be sorted by default (because it's bound to a PBGitCommit)
	[[commitList tableColumnWithIdentifier:@"SubjectColumn"] setSortDescriptorPrototype:[[NSSortDescriptor alloc] initWithKey:@"subject" ascending:YES]];
	// Add a menu that allows a user to select which columns to view
	[[commitList headerView] setMenu:[self tableColumnMenu]];

//	[historySplitView setTopMin:58.0 andBottomMin:100.0];
	[historySplitView setHidden:YES];
	[self performSelector:@selector(restoreSplitViewPositiion) withObject:nil afterDelay:0];

	[upperToolbarView setTopShade:237/255.0 bottomShade:216/255.0];
	[scopeBarView setTopColor:[NSColor colorWithCalibratedHue:0.579 saturation:0.068 brightness:0.898 alpha:1.000] 
				  bottomColor:[NSColor colorWithCalibratedHue:0.579 saturation:0.119 brightness:0.765 alpha:1.000]];
	[self updateBranchFilterMatrix];
    

	[super awakeFromNib];
	[fileBrowser setDelegate:self];
}

- (void)updateKeys
{
	PBGitCommit *lastObject = [[commitController selectedObjects] lastObject];
	if (lastObject) {
		if (![selectedCommit isEqual:lastObject]) {
			selectedCommit = lastObject;

			BOOL isOnHeadBranch = [selectedCommit isOnHeadBranch];
			[mergeButton setEnabled:!isOnHeadBranch];
			[cherryPickButton setEnabled:!isOnHeadBranch];
			[rebaseButton setEnabled:!isOnHeadBranch];
		}
	}
	else {
		[mergeButton setEnabled:NO];
		[cherryPickButton setEnabled:NO];
		[rebaseButton setEnabled:NO];
	}

	if (self.selectedCommitDetailsIndex == kHistoryTreeViewIndex) {
		self.gitTree = selectedCommit.tree;
		[self restoreFileBrowserSelection];
	}
	else {
		// kHistoryDetailViewIndex
		if (![self.webCommit isEqual:selectedCommit])
		self.webCommit = selectedCommit;
	}
}

- (void) updateBranchFilterMatrix
{
	if ([repository.currentBranch isSimpleRef]) {
		[allBranchesFilterItem setEnabled:YES];
		[localRemoteBranchesFilterItem setEnabled:YES];

		NSInteger filter = repository.currentBranchFilter;
		[allBranchesFilterItem setState:(filter == kGitXAllBranchesFilter)];
		[localRemoteBranchesFilterItem setState:(filter == kGitXLocalRemoteBranchesFilter)];
		[selectedBranchFilterItem setState:(filter == kGitXSelectedBranchFilter)];
	}
	else {
		[allBranchesFilterItem setState:NO];
		[localRemoteBranchesFilterItem setState:NO];

		[allBranchesFilterItem setEnabled:NO];
		[localRemoteBranchesFilterItem setEnabled:NO];

		[selectedBranchFilterItem setState:YES];
	}

	[selectedBranchFilterItem setTitle:[repository.currentBranch title]];
	[selectedBranchFilterItem sizeToFit];

	[localRemoteBranchesFilterItem setTitle:[[repository.currentBranch ref] isRemote] ? @"Remote" : @"Local"];
}

- (PBGitCommit *) firstCommit
{
	NSArray *arrangedObjects = [commitController arrangedObjects];
	if ([arrangedObjects count] > 0)
		return [arrangedObjects objectAtIndex:0];

	return nil;
}

- (BOOL)isCommitSelected
{
	return [selectedCommit isEqual:[[commitController selectedObjects] lastObject]];
}

- (void) setSelectedCommitDetailsIndex:(int)detailsIndex
{
	if (selectedCommitDetailsIndex == detailsIndex)
		return;

	selectedCommitDetailsIndex = detailsIndex;
	[[NSUserDefaults standardUserDefaults] setInteger:selectedCommitDetailsIndex forKey:kHistorySelectedDetailIndexKey];
	forceSelectionUpdate = YES;
	[self updateKeys];
}

- (void) updateStatus
{
	self.isBusy = repository.revisionList.isUpdating;
	self.status = [NSString stringWithFormat:@"%d commits loaded", [[commitController arrangedObjects] count]];
}

- (void) restoreFileBrowserSelection
{
	if (self.selectedCommitDetailsIndex != kHistoryTreeViewIndex)
		return;

	NSArray *children = [treeController content];
	if ([children count] == 0)
		return;

	NSIndexPath *path = [[NSIndexPath alloc] init];
	if ([currentFileBrowserSelectionPath count] == 0)
		path = [path indexPathByAddingIndex:0];
	else {
		for (NSString *pathComponent in currentFileBrowserSelectionPath) {
			PBGitTree *child = nil;
			NSUInteger childIndex = 0;
			for (child in children) {
				if ([child.path isEqualToString:pathComponent]) {
					path = [path indexPathByAddingIndex:childIndex];
					children = child.children;
					break;
				}
				childIndex++;
			}
			if (!child)
				return;
		}
	}

	[treeController setSelectionIndexPath:path];
}

- (void) saveFileBrowserSelection
{
	NSArray *objects = [treeController selectedObjects];
	NSArray *content = [treeController content];

	if ([objects count] && [content count]) {
		PBGitTree *treeItem = [objects objectAtIndex:0];
		currentFileBrowserSelectionPath = [treeItem.fullPath componentsSeparatedByString:@"/"];
	}
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([(NSString *)context isEqualToString: @"commitChange"]) {
		[self updateKeys];
		[self restoreFileBrowserSelection];
		[self updateSearch:filesSearchField];
	}else if ([(NSString *)context isEqualToString: @"treeChange"]) {
		[self updateQuicklookForce: NO];
		[self saveFileBrowserSelection];
	}else if([(NSString *)context isEqualToString:@"branchChange"]) {
		// Reset the sorting
		if ([[commitController sortDescriptors] count])
			[commitController setSortDescriptors:[NSArray array]];
		[self updateBranchFilterMatrix];
	}else if([(NSString *)context isEqualToString:@"updateRefs"]) {
		[commitController rearrangeObjects];
	}else if ([(NSString *)context isEqualToString:@"branchFilterChange"]) {
		[PBGitDefaults setBranchFilter:repository.currentBranchFilter];
		[self updateBranchFilterMatrix];
	}else if([(NSString *)context isEqualToString:@"updateCommitCount"] || [(NSString *)context isEqualToString:@"revisionListUpdating"]) {
		[self updateStatus];

		if (selectedCommitBeforeRefresh && [repository commitForSHA:[selectedCommitBeforeRefresh sha]])
			[self selectCommit:[selectedCommitBeforeRefresh sha]];
		else if ([repository.currentBranch isSimpleRef])
			[self selectCommit:[repository shaForRef:[repository.currentBranch ref]]];
		else
			[self selectCommit:[[self firstCommit] sha]];
	}else{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}

}

- (IBAction) openSelectedFile:(id)sender
{
	NSArray* selectedFiles = [treeController selectedObjects];
	if ([selectedFiles count] == 0)
		return;
	PBGitTree* tree = [selectedFiles objectAtIndex:0];
	NSString* name = [tree tmpFileNameForContents];
	[[NSWorkspace sharedWorkspace] openTempFile:name];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(setDetailedView:)) {
		[menuItem setState:(self.selectedCommitDetailsIndex == kHistoryDetailViewIndex) ? NSOnState : NSOffState];
    } else if ([menuItem action] == @selector(setTreeView:)) {
		[menuItem setState:(self.selectedCommitDetailsIndex == kHistoryTreeViewIndex) ? NSOnState : NSOffState];
    }
    return YES;
}

- (IBAction) setDetailedView:(id)sender
{
	self.selectedCommitDetailsIndex = kHistoryDetailViewIndex;
	forceSelectionUpdate = YES;
}

- (IBAction) setTreeView:(id)sender
{
	self.selectedCommitDetailsIndex = kHistoryTreeViewIndex;
	forceSelectionUpdate = YES;
}

- (IBAction) setBranchFilter:(id)sender
{
	repository.currentBranchFilter = [sender tag];
	[PBGitDefaults setBranchFilter:repository.currentBranchFilter];
	[self updateBranchFilterMatrix];
	forceSelectionUpdate = YES;
}

- (void)keyDown:(NSEvent*)event
{
	if ([[event charactersIgnoringModifiers] isEqualToString: @"f"] && [event modifierFlags] & NSAlternateKeyMask && [event modifierFlags] & NSCommandKeyMask)
		[superController.window makeFirstResponder: searchField];
	else
		[super keyDown: event];
}

// NSSearchField (actually textfields in general) prevent the normal Find operations from working. Setup custom actions for the
// next and previous menuitems (in MainMenu.nib) so they will work when the search field is active. When searching for text in
// a file make sure to call the Find panel's action method instead.
- (IBAction)selectNext:(id)sender
{
	NSResponder *firstResponder = [[[self view] window] firstResponder];
	if ([firstResponder isKindOfClass:[PBQLTextView class]]) {
		[(PBQLTextView *)firstResponder performFindPanelAction:sender];
		return;
	}

	[searchController selectNextResult];
}
- (IBAction)selectPrevious:(id)sender
{
	NSResponder *firstResponder = [[[self view] window] firstResponder];
	if ([firstResponder isKindOfClass:[PBQLTextView class]]) {
		[(PBQLTextView *)firstResponder performFindPanelAction:sender];
		return;
	}

	[searchController selectPreviousResult];
}

- (void) copyCommitInfo
{
	PBGitCommit *commit = [[commitController selectedObjects] objectAtIndex:0];
	if (!commit)
		return;
	NSString *info = [NSString stringWithFormat:@"%@ (%@)", [[commit realSha] substringToIndex:10], [commit subject]];

	NSPasteboard *a =[NSPasteboard generalPasteboard];
	[a declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[a setString:info forType: NSStringPboardType];
	
}

- (void) copyCommitSHA
{
	PBGitCommit *commit = [[commitController selectedObjects] objectAtIndex:0];
	if (!commit)
		return;
	NSString *info = [[commit realSha] substringWithRange:NSMakeRange(0, 7)];

	NSPasteboard *a =[NSPasteboard generalPasteboard];
	[a declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[a setString:info forType: NSStringPboardType];

}

- (IBAction)toggleQLPreviewPanel:(id)sender
{
    if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
        [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
    else
        [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
}

- (void) updateQuicklookForce:(BOOL)force
{
    [previewPanel reloadData];
}

- (IBAction) refresh:(id)sender
{
	selectedCommitBeforeRefresh = selectedCommit;
	[repository forceUpdateRevisions];
	selectedCommitBeforeRefresh = NULL;
}

- (void) updateView
{
	[self refresh: nil];
	[self updateKeys];
}

- (NSResponder *)firstResponder;
{
	return commitList;
}

- (void) scrollSelectionToTopOfViewFrom:(NSInteger)oldIndex
{
	if (oldIndex == NSNotFound)
		oldIndex = 0;

	NSInteger newIndex = [[commitController selectionIndexes] firstIndex];

	if (newIndex > oldIndex) {
        CGFloat sviewHeight = [[commitList superview] bounds].size.height;
        CGFloat rowHeight = [commitList rowHeight];
		NSInteger visibleRows = roundf(sviewHeight / rowHeight );
		newIndex += (visibleRows - 1);
		if (newIndex >= [[commitController content] count])
			newIndex = [[commitController content] count] - 1;
	}

    if (newIndex != oldIndex) {
        commitList.useAdjustScroll = YES;
    }

	[commitList scrollRowToVisible:newIndex];
    commitList.useAdjustScroll = NO;
}

- (NSArray *) selectedObjectsForSHA:(NSString *)commitSHA
{
	NSPredicate *selection = [NSPredicate predicateWithFormat:@"sha == %@", commitSHA];
	NSArray *selectedCommits = [[commitController content] filteredArrayUsingPredicate:selection];

	if (([selectedCommits count] == 0) && [self firstCommit])
		selectedCommits = [NSArray arrayWithObject:[self firstCommit]];

	return selectedCommits;
}

- (void)selectCommit:(NSString *)commitSHA
{
	if (!forceSelectionUpdate && [[[[commitController selectedObjects] lastObject] sha] isEqual:commitSHA])
		return;

	NSInteger oldIndex = [[commitController selectionIndexes] firstIndex];

	NSArray *selectedCommits = [self selectedObjectsForSHA:commitSHA];
	[commitController setSelectedObjects:selectedCommits];

	[self scrollSelectionToTopOfViewFrom:oldIndex];

	forceSelectionUpdate = NO;
}

- (BOOL) hasNonlinearPath
{
	return [commitController filterPredicate] || [[commitController sortDescriptors] count] > 0;
}

- (void)closeView
{
	[self saveSplitViewPosition];

	if (commitController) {
		[commitController removeObserver:self forKeyPath:@"selection"];
		[commitController removeObserver:self forKeyPath:@"arrangedObjects.@count"];
		[treeController removeObserver:self forKeyPath:@"selection"];

		[repository.revisionList removeObserver:self forKeyPath:@"isUpdating"];
		[repository removeObserver:self forKeyPath:@"currentBranch"];
		[repository removeObserver:self forKeyPath:@"refs"];
		[repository removeObserver:self forKeyPath:@"currentBranchFilter"];
	}

	[webHistoryController closeView];
	[fileView closeView];

	[super closeView];
}

#pragma mark Table Column Methods
- (NSMenu *)tableColumnMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Table columns menu"];
	for (NSTableColumn *column in [commitList tableColumns]) {
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setTitle:[[column headerCell] stringValue]];
		[item bind:@"value"
		  toObject:column
	   withKeyPath:@"hidden"
		   options:[NSDictionary dictionaryWithObject:@"NSNegateBoolean" forKey:NSValueTransformerNameBindingOption]];
		[menu addItem:item];
	}
	return menu;
}

#pragma mark Tree Context Menu Methods

- (void)showCommitsFromTree:(id)sender
{
	NSString *searchString = [(NSArray *)[sender representedObject] componentsJoinedByString:@" "];
	[searchController setHistorySearch:searchString mode:kGitXPathSearchMode];
}

- (void)showInFinderAction:(id)sender
{
	NSString *workingDirectory = [[repository workingDirectory] stringByAppendingString:@"/"];
	NSString *path;
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];

	for (NSString *filePath in [sender representedObject]) {
		path = [workingDirectory stringByAppendingPathComponent:filePath];
		[ws selectFile: path inFileViewerRootedAtPath:path];
	}

}

- (void)openFilesAction:(id)sender
{
	NSString *workingDirectory = [[repository workingDirectory] stringByAppendingString:@"/"];
	NSString *path;
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];

	for (NSString *filePath in [sender representedObject]) {
		path = [workingDirectory stringByAppendingPathComponent:filePath];
		[ws openFile:path];
	}
}

- (void) checkoutFiles:(id)sender
{
	NSMutableArray *files = [NSMutableArray array];
	for (NSString *filePath in [sender representedObject])
		[files addObject:[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];

	[repository checkoutFiles:files fromRefish:selectedCommit];
}

- (void) diffFilesAction:(id)sender
{
	[PBDiffWindowController showDiffWindowWithFiles:[sender representedObject] fromCommit:selectedCommit diffCommit:nil];
}

- (NSMenu *)contextMenuForTreeView
{
	NSArray *filePaths = [[treeController selectedObjects] valueForKey:@"fullPath"];

	NSMenu *menu = [[NSMenu alloc] init];
	for (NSMenuItem *item in [self menuItemsForPaths:filePaths])
		[menu addItem:item];
	return menu;
}

- (NSArray *)menuItemsForPaths:(NSArray *)paths
{
	NSMutableArray *filePaths = [NSMutableArray array];
	for (NSString *filePath in paths)
		[filePaths addObject:[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];

	BOOL multiple = [filePaths count] != 1;
	NSMenuItem *historyItem = [[NSMenuItem alloc] initWithTitle:multiple? @"Show history of files" : @"Show history of file"
														 action:@selector(showCommitsFromTree:)
												  keyEquivalent:@""];

	PBGitRef *headRef = [[repository headRef] ref];
	NSString *headRefName = [headRef shortName];
	NSString *diffTitle = [NSString stringWithFormat:@"Diff %@ with %@", multiple ? @"files" : @"file", headRefName];
	BOOL isHead = [[selectedCommit sha] isEqual:[repository headSHA]];
	NSMenuItem *diffItem = [[NSMenuItem alloc] initWithTitle:diffTitle
													  action:isHead ? nil : @selector(diffFilesAction:)
											   keyEquivalent:@""];

	NSMenuItem *checkoutItem = [[NSMenuItem alloc] initWithTitle:multiple ? @"Checkout files" : @"Checkout file"
														  action:@selector(checkoutFiles:)
												   keyEquivalent:@""];
	NSMenuItem *finderItem = [[NSMenuItem alloc] initWithTitle:@"Show in Finder"
														action:@selector(showInFinderAction:)
												 keyEquivalent:@""];
	NSMenuItem *openFilesItem = [[NSMenuItem alloc] initWithTitle:multiple? @"Open Files" : @"Open File"
														   action:@selector(openFilesAction:)
													keyEquivalent:@""];

	NSArray *menuItems = [NSArray arrayWithObjects:historyItem, diffItem, checkoutItem, finderItem, openFilesItem, nil];
	for (NSMenuItem *item in menuItems) {
		[item setTarget:self];
		[item setRepresentedObject:filePaths];
	}

	return menuItems;
}


#pragma mark NSSplitView delegate methods

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview
{
	return TRUE;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	NSUInteger index = [[splitView subviews] indexOfObject:subview];
	// this method (and canCollapse) are called by the splitView to decide how to collapse on double-click
	// we compare our two subviews, so that always the smaller one is collapsed.
	if([[[splitView subviews] objectAtIndex:index] frame].size.height < [[[splitView subviews] objectAtIndex:((index+1)%2)] frame].size.height) {
		return TRUE;
	}
	return FALSE;
}

// NSSplitView does not save and restore the position of the SplitView correctly so do it manually
- (void)saveSplitViewPosition
{
	float position = [[[historySplitView subviews] objectAtIndex:0] frame].size.height;
	[[NSUserDefaults standardUserDefaults] setFloat:position forKey:kHistorySplitViewPositionDefault];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

// make sure this happens after awakeFromNib
- (void)restoreSplitViewPositiion
{
	float position = [[NSUserDefaults standardUserDefaults] floatForKey:kHistorySplitViewPositionDefault];
	if (position < 1.0)
		position = 175;

	[historySplitView setPosition:position ofDividerAtIndex:0];
	[historySplitView setHidden:NO];
}


- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	if (proposedMin < 100)
		return 100;
	return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
    CGFloat max=[splitView frame].size.height - [splitView dividerThickness] - 100;
	if (max < proposedMax)
		return max;
    
	return proposedMax;
}


#pragma mark Repository Methods

- (IBAction) createBranch:(id)sender
{
	PBGitRef *currentRef = [repository.currentBranch ref];

	if (!selectedCommit || [selectedCommit hasRef:currentRef])
		[PBCreateBranchSheet beginCreateBranchSheetAtRefish:currentRef inRepository:self.repository];
	else
		[PBCreateBranchSheet beginCreateBranchSheetAtRefish:selectedCommit inRepository:self.repository];
}

- (IBAction) createTag:(id)sender
{
	if (!selectedCommit)
		[PBCreateTagSheet beginCreateTagSheetAtRefish:[repository.currentBranch ref] inRepository:repository];
	else
		[PBCreateTagSheet beginCreateTagSheetAtRefish:selectedCommit inRepository:repository];
}

- (IBAction) showAddRemoteSheet:(id)sender
{
	[PBAddRemoteSheet beginAddRemoteSheetForRepository:self.repository];
}

- (IBAction) merge:(id)sender
{
	if (selectedCommit)
		[repository mergeWithRefish:selectedCommit];
}

- (IBAction) cherryPick:(id)sender
{
	if (selectedCommit)
		[repository cherryPickRefish:selectedCommit];
}

- (IBAction) rebase:(id)sender
{
	if (selectedCommit)
		[repository rebaseBranch:nil onRefish:selectedCommit];
}

#pragma mark -
#pragma mark Quick Look Public API support

@protocol QLPreviewItem;

#pragma mark (QLPreviewPanelController)

- (BOOL) acceptsPreviewPanelControl:(id)panel
{
    return YES;
}

- (void)beginPreviewPanelControl:(id)panel
{
    // This document is now responsible of the preview panel
    // It is allowed to set the delegate, data source and refresh panel.
    previewPanel = panel;
	[previewPanel setDelegate:self];
	[previewPanel setDataSource:self];
}

- (void)endPreviewPanelControl:(id)panel
{
    // This document loses its responsisibility on the preview panel
    // Until the next call to -beginPreviewPanelControl: it must not
    // change the panel's delegate, data source or refresh it.
    previewPanel = nil;
}

#pragma mark <QLPreviewPanelDataSource>

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id)panel
{
    return [[fileBrowser selectedRowIndexes] count];
}

- (id <QLPreviewItem>)previewPanel:(id)panel previewItemAtIndex:(NSInteger)index
{
	PBGitTree *treeItem = (PBGitTree *)[[treeController selectedObjects] objectAtIndex:index];
	NSURL *previewURL = [NSURL fileURLWithPath:[treeItem tmpFileNameForContents]];

    return (id <QLPreviewItem>)previewURL;
}

#pragma mark <QLPreviewPanelDelegate>

- (BOOL)previewPanel:(id)panel handleEvent:(NSEvent *)event
{
    // redirect all key down events to the table view
    if ([event type] == NSKeyDown) {
        [fileBrowser keyDown:event];
        return YES;
    }
    return NO;
}

// This delegate method provides the rect on screen from which the panel will zoom.
- (NSRect)previewPanel:(id)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item
{
    NSInteger index = [fileBrowser rowForItem:[[treeController selectedNodes] objectAtIndex:0]];
    if (index == NSNotFound) {
        return NSZeroRect;
    }

    NSRect iconRect = [fileBrowser frameOfCellAtColumn:0 row:index];

    // check that the icon rect is visible on screen
    NSRect visibleRect = [fileBrowser visibleRect];

    if (!NSIntersectsRect(visibleRect, iconRect)) {
        return NSZeroRect;
    }

    // convert icon rect to screen coordinates
    iconRect = [fileBrowser convertRectToBase:iconRect];
    iconRect.origin = [[fileBrowser window] convertBaseToScreen:iconRect.origin];

    return iconRect;
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(PBSourceViewCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item 
{
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    PBGitTree *object = [item representedObject];
    NSString *workingDirectory = [[repository workingDirectory] stringByAppendingString:@"/"];
    NSString *path = [workingDirectory stringByAppendingPathComponent:[object fullPath]];
    NSImage *image = [workspace iconForFile:path];
    [image setSize:NSMakeSize(15, 15)];
    [cell setImage:image];
	
	NSColor *textColor = [NSColor blackColor];
	if ([object filterPredicate] && !([[filesSearchField stringValue] length] > 0 && [[object filterPredicate] evaluateWithObject:object])) {
		textColor = [NSColor lightGrayColor];
	}


	[cell setTextColor:textColor];
}

#pragma mark -

- (IBAction) updateSearch:(NSSearchField *) sender {
	static NSPredicate *predicateTemplate = nil;
	if (!predicateTemplate) {
		predicateTemplate = [NSPredicate predicateWithFormat:@"path CONTAINS[c] $SEARCH_STRING"];
	}
	
	NSString *searchString = [sender stringValue];
	NSPredicate *predicate = nil;
	if ([searchString length] > 0) {
		predicate = [predicateTemplate predicateWithSubstitutionVariables:
								  [NSDictionary dictionaryWithObject:searchString forKey:@"SEARCH_STRING"]];
	}
	[gitTree setFilterPredicate:predicate];
	[treeController setContent:[gitTree filteredChildren]];
}

@synthesize searchField;
@synthesize filesSearchField;
@synthesize fileBrowser;
@synthesize currentFileBrowserSelectionPath;
@synthesize webHistoryController;
@synthesize previewPanel;
@synthesize fileView;
@synthesize upperToolbarView;
@synthesize mergeButton;
@synthesize cherryPickButton;
@synthesize rebaseButton;
@synthesize scopeBarView;
@synthesize allBranchesFilterItem;
@synthesize localRemoteBranchesFilterItem;
@synthesize selectedBranchFilterItem;
@synthesize webView;
@synthesize forceSelectionUpdate;
@synthesize selectedCommit;
@synthesize selectedCommitBeforeRefresh;
@end
