//
//  PBGitSVTagItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBGitSVTagItem.h"


@implementation PBGitSVTagItem


+ (id)tagItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	PBGitSVTagItem *item = [self itemWithTitle:[[revSpecifier description] lastPathComponent]];
	item.revSpecifier = revSpecifier;
	
	return item;
}


- (NSImage *) icon
{
	static NSImage *tagImage = nil;
	if (!tagImage)
		tagImage = [NSImage imageNamed:@"Tag.png"];
	
	return tagImage;
}

@end
