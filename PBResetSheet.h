//
//  PBResetSheet.h
//  GitX
//
//  Created by Leszek Slazynski on 11-03-13.
//  Copyright 2011 LSL. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol PBGitRefish;
@class PBGitRepository;

typedef enum PBResetType {
    PBResetTypeNone,
    PBResetTypeSoft,
    PBResetTypeMixed,
    PBResetTypeHard,
    PBResetTypeMerge,
    PBResetTypeKeep
} PBResetType;

@interface PBResetSheet : NSWindowController {
    IBOutlet NSSegmentedControl* resetType;
    IBOutlet NSTabView* resetDesc;
    PBResetType defaultType;
    id<PBGitRefish> targetRefish;
    PBGitRepository* repository;
}

+ (void) beginResetSheetForRepository:(PBGitRepository*) repo refish:(id<PBGitRefish>)refish andType:(PBResetType)type;
- (IBAction)resetBranch:(id)sender;
- (IBAction)cancel:(id)sender;

@property (retain) NSSegmentedControl* resetType;
@property (retain) NSTabView* resetDesc;
@property (retain) id<PBGitRefish> targetRefish;
@property (retain) PBGitRepository* repository;
@end
