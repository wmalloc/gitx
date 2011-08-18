//
//  PBChangedFile.m
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBChangedFile.h"
#import "PBEasyPipe.h"

@implementation PBChangedFile

@synthesize path, status, hasStagedChanges, hasUnstagedChanges, commitBlobSHA, commitBlobMode;

- (id) initWithPath:(NSString *)p
{
	if (![super init])
		return nil;

	path = p;
	return self;
}

- (NSString *)indexInfo
{
	NSAssert(status == NEW || self.commitBlobSHA, @"File is not new, but doesn't have an index entry!");
	if (!self.commitBlobSHA)
		return [NSString stringWithFormat:@"0 0000000000000000000000000000000000000000\t%@", self.path];
	else
		return [NSString stringWithFormat:@"%@ %@\t%@", self.commitBlobMode, self.commitBlobSHA, self.path];
}

+ (NSImage *) iconForStatus:(PBChangedFileStatus) aStatus {
	NSString *filename;
	switch (aStatus) {
		case NEW:
			filename = @"unversioned_file";
			break;
		case DELETED:
			filename = @"deleted_file";
			break;
		case ADDED:
			filename = @"added_file";
			break;
		default:
			filename = @"modified_file";
			break;
	}
	NSString *p = [[NSBundle mainBundle] pathForResource:filename ofType:@"png"];
	return [[NSImage alloc] initByReferencingFile: p];
}

- (NSImage *) icon
{
	return [PBChangedFile iconForStatus:status];
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return NO;
}

@end
