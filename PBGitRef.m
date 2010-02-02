//
//  PBGitRef.m
//  GitX
//
//  Created by Pieter de Bie on 06-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRef.h"


NSString * const kGitXTagType    = @"tag";
NSString * const kGitXBranchType = @"branch";
NSString * const kGitXRemoteType = @"remote";

NSString * const kGitXTagRefPrefix    = @"refs/tags/";
NSString * const kGitXBranchRefPrefix = @"refs/heads/";
NSString * const kGitXRemoteRefPrefix = @"refs/remotes/";


@implementation PBGitRef

@synthesize ref;

- (NSString *)type
{
	if ([self isBranch])
		return @"head";
	if ([self isTag])
		return @"tag";
	if ([self isRemote])
		return @"remote";
	return nil;
}

- (BOOL)isBranch
{
	return [ref hasPrefix:kGitXBranchRefPrefix];
}

- (BOOL)isTag
{
	return [ref hasPrefix:kGitXTagRefPrefix];
}

- (BOOL)isRemote
{
	return [ref hasPrefix:kGitXRemoteRefPrefix];
}

- (BOOL)isEqual:(id)otherRef
{
	if (![otherRef isMemberOfClass:[PBGitRef class]])
		return NO;

	return [ref isEqualToString:[otherRef ref]];
}

- (NSUInteger)hash
{
	return [ref hash];
}

+ (PBGitRef*) refFromString: (NSString*) s
{
	return [[PBGitRef alloc] initWithString:s];
}

- (PBGitRef*) initWithString: (NSString*) s
{
	ref = s;
	return self;
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return NO;
}


#pragma mark <PBGitRefish>

- (NSString *)refishName
{
	return ref;
}

// everything after refs/<type>s/
- (NSString *)shortName
{
	if ([self type])
		return [ref substringFromIndex:[[self type] length] + 7];
	return ref;
}

- (NSString *)refishType
{
	if ([self isBranch])
		return kGitXBranchType;
	if ([self isTag])
		return kGitXTagType;
	if ([self isRemote])
		return kGitXRemoteType;
	return nil;
}

@end
