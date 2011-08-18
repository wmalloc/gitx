//
//  PBSourceViewItem.h
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBGitRevSpecifier;
@class PBGitRef;

@interface PBSourceViewItem : NSObject {
	NSMutableArray *children;

	NSString *title;
	PBGitRevSpecifier *revSpecifier;
	PBSourceViewItem *parent;

	BOOL isGroupItem;
	BOOL isUncollapsible;
	
	BOOL showsActionButton;
}
@property (nonatomic) BOOL showsActionButton;

+ (id)groupItemWithTitle:(NSString *)title;
+ (id)itemWithRevSpec:(PBGitRevSpecifier *)revSpecifier;
+ (id)itemWithTitle:(NSString *)title;

- (NSString *)badge;
- (NSString *)helpText;

- (void)addChild:(PBSourceViewItem *)child;
- (void)removeChild:(PBSourceViewItem *)child;

// This adds the ref to the path, which should match the item's title,
// so "refs/heads/pu/pb/sidebar" would have the path [@"pu", @"pb", @"sidebar"]
// to the 'local' branch thing
- (void)addRev:(PBGitRevSpecifier *)revSpecifier toPath:(NSArray *)path;
- (PBSourceViewItem *)findRev:(PBGitRevSpecifier *)rev;

- (PBGitRef *) ref;

@property(retain) NSString *title;
@property(readonly) NSMutableArray *children;
@property(assign) BOOL isGroupItem, isUncollapsible;
@property(retain) PBGitRevSpecifier *revSpecifier;
@property(retain) PBSourceViewItem *parent;
@property(readonly) NSImage *icon;
@end
