//
//  PBAddRemoteSheet.m
//  GitX
//
//  Created by Nathan Kinsinger on 12/8/09.
//  Copyright 2009 Nathan Kinsinger. All rights reserved.
//

#import "PBAddRemoteSheet.h"
#import "PBGitWindowController.h"
#import "PBGitRepository.h"



@interface PBAddRemoteSheet ()

- (void) beginAddRemoteSheetForRepository:(PBGitRepository *)repo;
- (void) openAddRemoteSheet;

@end


@implementation PBAddRemoteSheet


@synthesize repository;

@synthesize remoteNameTextField;
@synthesize remoteURLTextField;
@synthesize errorMessageTextField;

@synthesize browseSheetOpenPanel;
@synthesize browseAccessoryView;



#pragma mark -
#pragma mark PBAddRemoteSheet

+ (void) beginAddRemoteSheetForRepository:(PBGitRepository *)repo
{
	PBAddRemoteSheet *sheet = [[self alloc] initWithWindowNibName:@"PBAddRemoteSheet"];
	[sheet beginAddRemoteSheetForRepository:repo];
}


- (void) beginAddRemoteSheetForRepository:(PBGitRepository *)repo
{
	self.repository = repo;

	[self window];
	[self openAddRemoteSheet];
}


- (void) openAddRemoteSheet
{
	[self.errorMessageTextField setStringValue:@""];

	[NSApp beginSheet:[self window] modalForWindow:[self.repository.windowController window] modalDelegate:self didEndSelector:nil contextInfo:NULL];
}


- (void) browseSheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)code contextInfo:(void *)info
{
    [sheet orderOut:self];

    if (code == NSOKButton)
		[self.remoteURLTextField setStringValue:[(NSOpenPanel *)sheet filename]];

	[self openAddRemoteSheet];
}

#pragma mark IBActions

- (IBAction) browseFolders:(id)sender
{
	[self orderOutAddRemoteSheet:nil];

    self.browseSheetOpenPanel = [NSOpenPanel openPanel];

	[browseSheetOpenPanel setTitle:@"Add remote"];
    [browseSheetOpenPanel setMessage:@"Select a folder with a git repository"];
    [browseSheetOpenPanel setCanChooseFiles:NO];
    [browseSheetOpenPanel setCanChooseDirectories:YES];
    [browseSheetOpenPanel setAllowsMultipleSelection:NO];
    [browseSheetOpenPanel setCanCreateDirectories:NO];
	[browseSheetOpenPanel setAccessoryView:browseAccessoryView];

    [browseSheetOpenPanel beginSheetForDirectory:nil file:nil types:nil
						 modalForWindow:[self.repository windowForSheet]
						  modalDelegate:self
						 didEndSelector:@selector(browseSheetDidEnd:returnCode:contextInfo:)
							contextInfo:NULL];
}


- (IBAction) addRemote:(id)sender
{
	[self.errorMessageTextField setStringValue:@""];

	NSString *name = [[self.remoteNameTextField stringValue] copy];

	if ([name isEqualToString:@""]) {
		[self.errorMessageTextField setStringValue:@"Remote name is required"];
		return;
	}

	if (![self.repository checkRefFormat:[@"refs/remotes/" stringByAppendingString:name]]) {
		[self.errorMessageTextField setStringValue:@"Invalid remote name"];
		return;
	}

	NSString *url = [[self.remoteURLTextField stringValue] copy];
	if ([url isEqualToString:@""]) {
		[self.errorMessageTextField setStringValue:@"Remote URL is required"];
		return;
	}

	[self orderOutAddRemoteSheet:self];
	[self.repository beginAddRemote:name forURL:url];
}


- (IBAction) orderOutAddRemoteSheet:(id)sender
{
	[NSApp endSheet:[self window]];
    [[self window] orderOut:self];
}


- (IBAction) showHideHiddenFiles:(id)sender
{
	// This uses undocumented OpenPanel features to show hidden files (required for 10.5 support)
	NSNumber *showHidden = [NSNumber numberWithBool:[sender state] == NSOnState];
	[[self.browseSheetOpenPanel valueForKey:@"_navView"] setValue:showHidden forKey:@"showsHiddenFiles"];
}


@end
