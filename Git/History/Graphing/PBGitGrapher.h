//
//  PBGitGrapher.h
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitCommit.h"
#import "PBGitGraphLine.h"
#import "PBGraphCellInfo.h"

void add_line(struct PBGitGraphLine *lines, int *nLines, int upper, int from, int to, int index);

@interface PBGitGrapher : NSObject
{
	PBGraphCellInfo *previous;
	void *pl;
	int curLane;
}

- (id) initWithRepository:(PBGitRepository *)repo;
- (void) decorateCommit:(PBGitCommit *)commit;
@end
