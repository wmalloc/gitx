//
//  PBGitSVRemoteItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVRemoteItem.h"
#import "PBGitRef.h"


@implementation PBGitSVRemoteItem

@synthesize alert;
@synthesize helpText;

+ (id)remoteItemWithTitle:(NSString *)title
{
	PBGitSVRemoteItem *item = [self itemWithTitle:title];
	
	return item;
}


- (NSImage *) icon
{
	static NSImage *networkImage = nil;
	if (!networkImage) {
		networkImage = [NSImage imageNamed:NSImageNameNetwork];
		[networkImage setSize:NSMakeSize(16,16)];
	}
	
	return networkImage;
}


- (PBGitRef *) ref
{
	return [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:self.title]];
}

- (NSString *)badge
{
	return (alert ? @"!" : nil);
}
@end
