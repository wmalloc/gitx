//
//  PBStashContentController.h
//  GitX
//
//  Created by David Catmull on 20-06-11.
//  Copyright 2011. All rights reserved.
//

#import "PBViewController.h"
#import "PBWebHistoryController.h"

@class PBGitStash;
@class PBWebStashController;

// Controls the view displaying a stash diff
@interface PBStashContentController : PBViewController {
	IBOutlet id webView;
	IBOutlet PBWebStashController *unstagedController;
	IBOutlet PBWebStashController *stagedController;
}

- (void) showStash:(PBGitStash*)stash;

@property (retain) id webView;
@property (retain) PBWebStashController *unstagedController;
@property (retain) PBWebStashController *stagedController;
@end
