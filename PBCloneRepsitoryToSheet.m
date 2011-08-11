//
//  PBCloneRepsitoryToSheet.m
//  GitX
//
//  Created by Nathan Kinsinger on 2/7/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBCloneRepsitoryToSheet.h"
#import "PBGitRepository.h"



@interface PBCloneRepsitoryToSheet ()

- (void) beginCloneRepsitoryToSheetForRepository:(PBGitRepository *)repo;

@end


@implementation PBCloneRepsitoryToSheet

@synthesize repository;
@synthesize isBare;
@synthesize message;
@synthesize cloneToAccessoryView;


#pragma mark -
#pragma mark PBCloneRepsitoryToSheet

+ (void) beginCloneRepsitoryToSheetForRepository:(PBGitRepository *)repo
{
	PBCloneRepsitoryToSheet *sheet = [[self alloc] initWithWindowNibName:@"PBCloneRepsitoryToSheet"];
	[sheet beginCloneRepsitoryToSheetForRepository:repo];
}


- (void) beginCloneRepsitoryToSheetForRepository:(PBGitRepository *)repo
{
	self.repository = repo;
	[self window];
}


- (void) awakeFromNib
{
    NSOpenPanel *cloneToSheet = [NSOpenPanel openPanel];

	[cloneToSheet setTitle:@"Clone Repository To"];
	[cloneToSheet setPrompt:@"Clone"];
    [self.message setStringValue:[NSString stringWithFormat:@"Select a folder to clone %@ into", [self.repository projectName]]];
    [cloneToSheet setCanSelectHiddenExtension:NO];
    [cloneToSheet setCanChooseFiles:NO];
    [cloneToSheet setCanChooseDirectories:YES];
    [cloneToSheet setAllowsMultipleSelection:NO];
    [cloneToSheet setCanCreateDirectories:YES];
	[cloneToSheet setAccessoryView:cloneToAccessoryView];

    [cloneToSheet beginSheetModalForWindow:[self.repository windowForSheet] 
                         completionHandler:^(NSInteger result) {
                             [cloneToSheet orderOut:self];
                             
                             if (result == NSOKButton)
                             {
                                 NSURL *url = [cloneToSheet URL];
                                 DLog(@"clone path = %@", url.path);
                                 [self.repository cloneRepositoryToPath:url.path bare:self.isBare];
                             }
                         }];
}
	
@end
