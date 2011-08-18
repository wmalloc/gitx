//
//  PBGitLane.m
//  GitX
//
//  Created by Pieter de Bie on 27-08-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitLane.h"
int PBGitLane::s_colorIndex = 0;

int PBGitLane::index() const
{
	return d_index;
}

void PBGitLane::setSha(NSString *sha)
{
	d_sha = sha;
}

void PBGitLane::resetColors()
{
	s_colorIndex = 0;
}
