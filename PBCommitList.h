//
//  PBCommitList.h
//  GitX
//
//  Created by Pieter de Bie on 9/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebView.h>
#import "PBGitHistoryController.h"

@class PBWebHistoryController;

// Displays the list of commits. Additional behavior includes special key
// handling and hiliting search results.
// dataSource: PBRefController
// delegate: PBGitHistoryController
@interface PBCommitList : NSTableView
{
@private
	WebView* _webView;
	PBWebHistoryController *_webHistoryController;
	PBGitHistoryController *_gitHistoryController;
	PBHistorySearchController *_historySearchController;

    BOOL _useAdjustScroll;
	NSPoint _mouseDownPoint;
}

@property (retain) IBOutlet WebView* webView;
@property (retain) IBOutlet PBWebHistoryController *webHistoryController;
@property (retain) IBOutlet PBGitHistoryController *gitHistoryController;
@property (retain) IBOutlet PBHistorySearchController *historySearchController;

@property (readonly) NSPoint mouseDownPoint;
@property (assign) BOOL useAdjustScroll;
@end
