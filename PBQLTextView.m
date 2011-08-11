//
//  PBQLTextView.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/22/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBQLTextView.h"
#import "PBGitHistoryController.h"


@implementation PBQLTextView
@synthesize gitHistoryController = _gitHistoryController;

- (void) keyDown: (NSEvent *) event
{
	if ([[event characters] isEqualToString:@" "]) {
		[_gitHistoryController toggleQLPreviewPanel:self];
		return;
	}
	
	[super keyDown:event];
}

- (void)dealloc
{
    [_gitHistoryController release];
    
    [super dealloc];
}
@end
