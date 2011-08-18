//
//  PBGitHistoryList.h
//  GitX
//
//  Created by Nathan Kinsinger on 2/20/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class PBGitRepository;
@class PBGitRevSpecifier;
@class PBGitRef;
@class PBGitRevList;
@class PBGitHistoryGrapher;

@interface PBGitHistoryList : NSObject {
	PBGitRepository *repository;

	PBGitRevList *projectRevList;
	PBGitRevList *currentRevList;

	NSString *lastSHA;
	NSSet *lastRefSHAs;
	NSInteger lastBranchFilter;
	PBGitRef *lastRemoteRef;
	BOOL resetCommits;
	BOOL shouldReloadProjectHistory;

	PBGitHistoryGrapher *grapher;
	NSOperationQueue *graphQueue;

	NSMutableArray *commits;
	BOOL isUpdating;
}

- (id) initWithRepository:(PBGitRepository *)repo;
- (void) forceUpdate;
- (void) updateHistory;
- (void)cleanup;

- (void) updateCommitsFromGrapher:(NSDictionary *)commitData;


@property (retain) PBGitRevList *projectRevList;
@property (retain) NSMutableArray *commits;
@property (readonly) NSArray *projectCommits;
@property (assign) BOOL isUpdating;

@property (retain) PBGitRepository *repository;
@property (retain) NSString *lastSHA;
@property (retain) NSSet *lastRefSHAs;
@property NSInteger lastBranchFilter;
@property (retain) PBGitRef *lastRemoteRef;
@property BOOL resetCommits;
@property BOOL shouldReloadProjectHistory;
@property (retain) NSOperationQueue *graphQueue;
@end
