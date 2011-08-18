//
//  PBGitIndexController.m
//  GitX
//
//  Created by Pieter de Bie on 18-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBGitIndexController.h"
#import "PBChangedFile.h"
#import "PBGitRepository.h"
#import "PBGitIndex.h"

#define FileChangesTableViewType @"GitFileChangedType"

@interface PBGitIndexController ()
- (void)discardChangesForFiles:(NSArray *)files force:(BOOL)force;
@end

@implementation PBGitIndexController

- (void)awakeFromNib
{
	[unstagedTable setDoubleAction:@selector(tableClicked:)];
	[stagedTable setDoubleAction:@selector(tableClicked:)];

	[unstagedTable setTarget:self];
	[stagedTable setTarget:self];

	[unstagedTable registerForDraggedTypes: [NSArray arrayWithObject:FileChangesTableViewType]];
	[stagedTable registerForDraggedTypes: [NSArray arrayWithObject:FileChangesTableViewType]];
}

// FIXME: Find a proper place for this method -- this is not it.
- (void)ignoreFiles:(NSArray *)files
{
	// Build output string
	NSMutableArray *fileList = [NSMutableArray array];
	for (PBChangedFile *file in files) {
		NSString *name = file.path;
		if ([name length] > 0)
			[fileList addObject:name];
	}
	NSString *filesAsString = [fileList componentsJoinedByString:@"\n"];

	// Write to the file
	NSString *gitIgnoreName = [commitController.repository gitIgnoreFilename];

	NSStringEncoding enc = NSUTF8StringEncoding;
	NSError *error = nil;
	NSMutableString *ignoreFile;

	if (![[NSFileManager defaultManager] fileExistsAtPath:gitIgnoreName]) {
		ignoreFile = [filesAsString mutableCopy];
	} else {
		ignoreFile = [NSMutableString stringWithContentsOfFile:gitIgnoreName usedEncoding:&enc error:&error];
		if (error) {
			[[commitController.repository windowController] showErrorSheet:error];
			return;
		}
		// Add a newline if not yet present
		if ([ignoreFile characterAtIndex:([ignoreFile length] - 1)] != '\n')
			[ignoreFile appendString:@"\n"];
		[ignoreFile appendString:filesAsString];
	}

	[ignoreFile writeToFile:gitIgnoreName atomically:YES encoding:enc error:&error];
	if (error)
		[[commitController.repository windowController] showErrorSheet:error];
}

# pragma mark Context Menu methods
- (BOOL) allSelectedCanBeIgnored:(NSArray *)selectedFiles
{
	for (PBChangedFile *selectedItem in selectedFiles) {
		if (selectedItem.status != NEW) {
			return NO;
		}
	}
	return YES;
}

- (NSMenu *) menuForTable:(NSTableView *)table
{
	NSMenu *menu = [[NSMenu alloc] init];
	id controller = [table tag] == 0 ? unstagedFilesController : stagedFilesController;
	NSArray *selectedFiles = [controller selectedObjects];

	// Unstaged changes
	if ([table tag] == 0) {
		NSMenuItem *stageItem = [[NSMenuItem alloc] initWithTitle:@"Stage Changes" action:@selector(stageFilesAction:) keyEquivalent:@""];
		[stageItem setTarget:self];
		[stageItem setRepresentedObject:selectedFiles];
		[menu addItem:stageItem];
	}
	else if ([table tag] == 1) {
		NSMenuItem *unstageItem = [[NSMenuItem alloc] initWithTitle:@"Unstage Changes" action:@selector(unstageFilesAction:) keyEquivalent:@""];
		[unstageItem setTarget:self];
		[unstageItem setRepresentedObject:selectedFiles];
		[menu addItem:unstageItem];
	}

	NSString *title = [selectedFiles count] == 1 ? @"Open file" : @"Open files";
	NSMenuItem *openItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(openFilesAction:) keyEquivalent:@""];
	[openItem setTarget:self];
	[openItem setRepresentedObject:selectedFiles];
	[menu addItem:openItem];

	// Attempt to ignore
	if ([self allSelectedCanBeIgnored:selectedFiles]) {
		NSString *ignoreText = [selectedFiles count] == 1 ? @"Ignore File": @"Ignore Files";
		NSMenuItem *ignoreItem = [[NSMenuItem alloc] initWithTitle:ignoreText action:@selector(ignoreFilesAction:) keyEquivalent:@""];
		[ignoreItem setTarget:self];
		[ignoreItem setRepresentedObject:selectedFiles];
		[menu addItem:ignoreItem];
		
		if ([selectedFiles count] == 1) {
			NSString *path = [[selectedFiles objectAtIndex:0] path];
			NSString *extension = [path pathExtension];
			if ([extension length] > 0) {
				ignoreText = [NSString stringWithFormat:@"Ignore Files with extension (.%@)", extension];
				ignoreItem = [[NSMenuItem alloc] initWithTitle:ignoreText action:@selector(ignoreFilesWithExtensionAction:) keyEquivalent:@""];
				[ignoreItem setTarget:self];
				[ignoreItem setRepresentedObject:extension];
				[menu addItem:ignoreItem];
				[ignoreItem release];
			}
		}
	}

	if ([selectedFiles count] == 1) {
		NSMenuItem *showInFinderItem = [[NSMenuItem alloc] initWithTitle:@"Show in Finder" action:@selector(showInFinderAction:) keyEquivalent:@""];
		[showInFinderItem setTarget:self];
		[showInFinderItem setRepresentedObject:selectedFiles];
		[menu addItem:showInFinderItem];
    }

	for (PBChangedFile *file in selectedFiles)
		if (!file.hasUnstagedChanges)
			return menu;

	NSMenuItem *discardItem = [[NSMenuItem alloc] initWithTitle:@"Discard changes…" action:@selector(discardFilesAction:) keyEquivalent:@""];
	[discardItem setTarget:self];
	[discardItem setAlternate:NO];
	[discardItem setRepresentedObject:selectedFiles];

	[menu addItem:discardItem];

	NSMenuItem *discardForceItem = [[NSMenuItem alloc] initWithTitle:@"Discard changes" action:@selector(forceDiscardFilesAction:) keyEquivalent:@""];
	[discardForceItem setTarget:self];
	[discardForceItem setAlternate:YES];
	[discardForceItem setRepresentedObject:selectedFiles];
	[discardForceItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
	[menu addItem:discardForceItem];
	
	return menu;
}

- (void) stageFilesAction:(id) sender
{
	[commitController.index stageFiles:[sender representedObject]];
}

- (void) unstageFilesAction:(id) sender
{
	[commitController.index unstageFiles:[sender representedObject]];
}

- (void) openFilesAction:(id) sender
{
	NSArray *files = [sender representedObject];
	NSString *workingDirectory = [commitController.repository workingDirectory];
	for (PBChangedFile *file in files)
		[[NSWorkspace sharedWorkspace] openFile:[workingDirectory stringByAppendingPathComponent:[file path]]];
}

- (void) ignoreFilesAction:(id) sender
{
	NSArray *selectedFiles = [sender representedObject];
	if ([selectedFiles count] == 0)
		return;

	[self ignoreFiles:selectedFiles];
	[commitController.index refresh];
}

- (void) ignoreFilesWithExtensionAction:(id) sender {
	NSString *extension = [sender representedObject];
	if ([extension length] == 0)
		return;
	PBChangedFile *file = [[PBChangedFile alloc] initWithPath:[NSString stringWithFormat:@"*.%@", extension]];
	
	
	[self ignoreFiles:[NSArray arrayWithObject:file]];
	[file release];
	[commitController.index refresh];
}

- (void)discardFilesAction:(id) sender
{
	NSArray *selectedFiles = [sender representedObject];
	if ([selectedFiles count] > 0)
		[self discardChangesForFiles:selectedFiles force:FALSE];
}

- (void)forceDiscardFilesAction:(id) sender
{
	NSArray *selectedFiles = [sender representedObject];
	if ([selectedFiles count] > 0)
		[self discardChangesForFiles:selectedFiles force:TRUE];
}

- (void) showInFinderAction:(id) sender
{
	NSArray *selectedFiles = [sender representedObject];
	if ([selectedFiles count] == 0)
		return;
	NSString *workingDirectory = [[commitController.repository workingDirectory] stringByAppendingString:@"/"];
	NSString *path = [workingDirectory stringByAppendingPathComponent:[[selectedFiles objectAtIndex:0] path]];
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	[ws selectFile: path inFileViewerRootedAtPath:nil];
}

- (void) discardChangesForFilesAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[alert window] orderOut:nil];

	if (returnCode == NSAlertDefaultReturn) {
        [commitController.index discardChangesForFiles:contextInfo];
	}
}

- (void) discardChangesForFiles:(NSArray *)files force:(BOOL)force
{
	if (!force) {
		NSAlert *alert = [NSAlert alertWithMessageText:@"Discard changes"
                                         defaultButton:nil
                                       alternateButton:@"Cancel"
                                           otherButton:nil
                             informativeTextWithFormat:@"Are you sure you wish to discard the changes to this file?\n\nYou cannot undo this operation."];
        [alert beginSheetModalForWindow:[[commitController view] window]
                          modalDelegate:self
                         didEndSelector:@selector(discardChangesForFilesAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:files];
	} else {
        [commitController.index discardChangesForFiles:files];
    }
}

# pragma mark TableView icon delegate
- (void)tableView:(NSTableView*)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
	id controller = [tableView tag] == 0 ? unstagedFilesController : stagedFilesController;
	PBChangedFile *changedFile = [[controller arrangedObjects] objectAtIndex:rowIndex];
	PBChangedFileStatus status = [changedFile status];
	NSImage *imageToSet = [changedFile icon];
	if (controller == stagedFilesController && status == NEW) {
		imageToSet = [PBChangedFile iconForStatus:ADDED];
	}
	[[tableColumn dataCell] setImage:imageToSet];
}

- (void) tableClicked:(NSTableView *) tableView
{
	NSArrayController *controller = [tableView tag] == 0 ? unstagedFilesController : stagedFilesController;

	NSIndexSet *selectionIndexes = [tableView selectedRowIndexes];
	NSArray *files = [[controller arrangedObjects] objectsAtIndexes:selectionIndexes];
	if ([tableView tag] == 0)
		[commitController.index stageFiles:files];
	else
		[commitController.index unstageFiles:files];
}

- (void) rowClicked:(NSCell *)sender
{
	NSTableView *tableView = (NSTableView *)[sender controlView];
	if([tableView numberOfSelectedRows] != 1)
		return;
	[self tableClicked: tableView];
}

- (BOOL)tableView:(NSTableView *)tv
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
	 toPasteboard:(NSPasteboard*)pboard
{
    // Copy the row numbers to the pasteboard.
    [pboard declareTypes:[NSArray arrayWithObjects:FileChangesTableViewType, NSFilenamesPboardType, nil] owner:self];

	// Internal, for dragging from one tableview to the other
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard setData:data forType:FileChangesTableViewType];

	// External, to drag them to for example XCode or Textmate
	NSArrayController *controller = [tv tag] == 0 ? unstagedFilesController : stagedFilesController;
	NSArray *files = [[controller arrangedObjects] objectsAtIndexes:rowIndexes];
	NSString *workingDirectory = [commitController.repository workingDirectory];

	NSMutableArray *filenames = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
	for (PBChangedFile *file in files)
		[filenames addObject:[workingDirectory stringByAppendingPathComponent:[file path]]];

	[pboard setPropertyList:filenames forType:NSFilenamesPboardType];
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tableView
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)operation
{
	if ([info draggingSource] == tableView)
		return NSDragOperationNone;

	[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
    return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)aTableView
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData* rowData = [pboard dataForType:FileChangesTableViewType];
    NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];

	NSArrayController *controller = [aTableView tag] == 0 ? stagedFilesController : unstagedFilesController;
	NSArray *files = [[controller arrangedObjects] objectsAtIndexes:rowIndexes];

	if ([aTableView tag] == 0)
		[commitController.index unstageFiles:files];
	else
		[commitController.index stageFiles:files];

	return YES;
}

@synthesize commitController;
@synthesize unstagedTable;
@synthesize stagedTable;
@end
