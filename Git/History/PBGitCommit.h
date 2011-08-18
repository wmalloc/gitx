//
//  PBGitCommit.h
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRepository.h"
#import "PBGitTree.h"
#import "PBGitRefish.h"


extern NSString * const kGitXCommitType;


@interface PBGitCommit : NSObject <PBGitRefish> {
	NSString *sha;

	NSString* subject;
	NSString* author;
	NSString *committer;
	NSString* details;
	NSString *_patch;
	NSArray *parents;
	NSString *realSHA;

	int timestamp;
	char sign;
	id lineInfo;
	PBGitRepository* repository;
}

+ (PBGitCommit *)commitWithRepository:(PBGitRepository*)repo andSha:(NSString *)newSha;
- (id)initWithRepository:(PBGitRepository *)repo andSha:(NSString *)newSha;

- (void) addRef:(PBGitRef *)ref;
- (void) removeRef:(id)ref;
- (BOOL) hasRef:(PBGitRef *)ref;

- (NSString *)realSha;
- (BOOL) isOnSameBranchAs:(PBGitCommit *)other;
- (BOOL) isOnHeadBranch;

// <PBGitRefish>
- (NSString *) refishName;
- (NSString *) shortName;
- (NSString *) refishType;

@property (readonly) NSString *sha;
@property (copy) NSString* subject;
@property (copy) NSString* author;
@property (copy) NSString *committer;
@property (retain) NSArray *parents;

@property (assign) int timestamp;

@property (retain) NSMutableArray* refs;
@property (readonly) NSDate *date;
@property (readonly) NSString* dateString;
@property (readonly) NSString* patch;
@property (assign) char sign;

@property (readonly) NSString* details;
@property (readonly) PBGitTree* tree;
@property (readonly) NSArray* treeContents;
@property (retain) PBGitRepository* repository;
@property (retain) id lineInfo;
@property (retain) NSString *_patch;
@property (retain) NSString *realSHA;
@end
