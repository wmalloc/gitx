//
//  PBGitRef.h
//  GitX
//
//  Created by Pieter de Bie on 06-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRefish.h"


extern NSString * const kGitXTagRefPrefix;
extern NSString * const kGitXBranchRefPrefix;
extern NSString * const kGitXRemoteRefPrefix;


@interface PBGitRef : NSObject <PBGitRefish> {
	NSString* ref;
}

// <PBGitRefish>
- (NSString *)refishName;
- (NSString *)shortName;
- (NSString *)refishType;

- (NSString *)type;
- (BOOL)isBranch;
- (BOOL)isTag;
- (BOOL)isRemote;

+ (PBGitRef*) refFromString: (NSString*) s;
- (PBGitRef*) initWithString: (NSString*) s;
@property(readonly) NSString* ref;

@end
