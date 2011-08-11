//
//  GitTest_AppDelegate.h
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright __MyCompanyName__ 2008 . All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRepository.h"

@class PBCloneRepositoryPanel;

@interface GitXAppDelegate : NSObject PROTOCOL_10_6(NSApplicationDelegate)
{
    NSWindow *_window;
	id _firstResponder;
	NSPersistentStoreCoordinator *_persistentStoreCoordinator;
	NSManagedObjectModel *_managedObjectModel;
	NSManagedObjectContext *_managedObjectContext;

	PBCloneRepositoryPanel *_cloneRepositoryPanel;
}

@property (retain) IBOutlet NSWindow *window;
@property (retain) IBOutlet id firstResponder;
@property (retain) PBCloneRepositoryPanel *cloneRepositoryPanel;

@property (retain) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (retain) NSManagedObjectModel *managedObjectModel;
@property (retain) NSManagedObjectContext *managedObjectContext;

- (IBAction)openPreferencesWindow:(id)sender;
- (IBAction)showAboutPanel:(id)sender;

- (IBAction)installCliTool:(id)sender;

- (IBAction)saveAction:sender;
- (IBAction)showHelp:(id)sender;
- (IBAction)reportAProblem:(id)sender;

- (IBAction)showCloneRepository:(id)sender;
@end
