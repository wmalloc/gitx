//
//  PBCommitList.m
//  GitX
//
//  Created by Pieter de Bie on 9/11/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBCommitList.h"
#import "PBGitRevisionCell.h"
#import "PBWebHistoryController.h"
#import "PBHistorySearchController.h"

@implementation PBCommitList
@synthesize webView = _webView;
@synthesize webHistoryController = _webHistoryController;
@synthesize gitHistoryController = _gitHistoryController;
@synthesize historySearchController = _historySearchController;
@synthesize mouseDownPoint = _mouseDownPoint;
@synthesize useAdjustScroll = _useAdjustScroll;

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)local
{
	return NSDragOperationCopy;
}

- (void)keyDown:(NSEvent *)event
{
	NSString* character = [event charactersIgnoringModifiers];

	// Pass on command-shift up/down to the responder. We want the splitview to capture this.
	if ([event modifierFlags] & NSShiftKeyMask && [event modifierFlags] & NSCommandKeyMask && ([event keyCode] == 0x7E || [event keyCode] == 0x7D)) {
		[self.nextResponder keyDown:event];
		return;
	}

	if([character isEqualToString:@" "])
    {
		if (_gitHistoryController.selectedCommitDetailsIndex == 0)
        {
			if ([event modifierFlags] & NSShiftKeyMask)
				[_webView scrollPageUp:self];
			else
				[_webView scrollPageDown:self];
		} else {
			[_gitHistoryController toggleQLPreviewPanel:self];
        }
	} else if ([character rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"jkcv"]].location == 0)
		[_webHistoryController sendKey: character];
	else
		[super keyDown: event];
}

- (void)copy:(id)sender
{
	[_gitHistoryController copyCommitInfo];
}

- (void)copySHA:(id)sender
{
	[_gitHistoryController copyCommitSHA];
}

// !!! Andre Berg 20100330: Used from -scrollSelectionToTopOfViewFrom: of PBGitHistoryController
// so that when the history controller udpates the branch filter the origin of the superview gets
// shifted into multiples of the row height. Otherwise the top selected row will always be off by
// a little bit depending on how much the bottom half of the split view is dragged down.
- (NSRect)adjustScroll:(NSRect)proposedVisibleRect
{
    //DLog(@"[%@ %s]: proposedVisibleRect: %@", [self class], _cmd, NSStringFromRect(proposedVisibleRect));
    NSRect newRect = proposedVisibleRect;

    // !!! Andre Berg 20100330: only modify if -scrollSelectionToTopOfViewFrom: has set useAdjustScroll to YES
    // Otherwise we'd also constrain things like middle mouse scrolling.
    if (_useAdjustScroll)
    {
        NSInteger rh = [self rowHeight];
        NSInteger ny = (NSInteger)proposedVisibleRect.origin.y % (NSInteger)rh;
        NSInteger adj = rh - ny;
        // check the targeted row and see if we need to add or subtract the difference (if there is one)...
        NSRect sr = [self rectOfRow:[self selectedRow]];
        // DLog(@"[%@ %s]: selectedRow %d, rect: %@", [self class], _cmd, [self selectedRow], NSStringFromRect(sr));
        if (sr.origin.y > proposedVisibleRect.origin.y) {
            // DLog(@"[%@ %s] selectedRow.origin.y > proposedVisibleRect.origin.y. adding adj (%d)", [self class], _cmd, adj);
            newRect = NSMakeRect(newRect.origin.x, newRect.origin.y + adj, newRect.size.width, newRect.size.height);
        } else if (sr.origin.y < proposedVisibleRect.origin.y) {
            // DLog(@"[%@ %s] selectedRow.origin.y < proposedVisibleRect.origin.y. subtracting ny (%d)", [self class], _cmd, ny);
            newRect = NSMakeRect(newRect.origin.x, newRect.origin.y - ny , newRect.size.width, newRect.size.height);
        } else {
            // DLog(@"[%@ %s] selectedRow.origin.y == proposedVisibleRect.origin.y. leaving as is", [self class], _cmd);
        }
    }
    //DLog(@"[%@ %s]: newRect: %@", [self class], _cmd, NSStringFromRect(newRect));
    return newRect;
}

- (void)mouseDown:(NSEvent *)theEvent
{
	_mouseDownPoint = [[self window] mouseLocationOutsideOfEventStream];
	[super mouseDown:theEvent];
}

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows
							tableColumns:(NSArray *)tableColumns
								   event:(NSEvent *)dragEvent
								  offset:(NSPointPointer)dragImageOffset
{
	NSPoint location = [self convertPointFromBase:_mouseDownPoint];
	int row = [self rowAtPoint:location];
	int column = [self columnAtPoint:location];
	PBGitRevisionCell *cell = (PBGitRevisionCell *)[self preparedCellAtColumn:column row:row];
	NSRect cellFrame = [self frameOfCellAtColumn:column row:row];

	int index = [cell indexAtX:(location.x - cellFrame.origin.x)];
	if (index == -1)
		return [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];

	NSRect rect = [cell rectAtIndex:index];

	NSImage *newImage = [[NSImage alloc] initWithSize:NSMakeSize(rect.size.width + 3, rect.size.height + 3)];
	rect.origin = NSMakePoint(0.5, 0.5);

	[newImage lockFocus];
	[cell drawLabelAtIndex:index inRect:rect];
	[newImage unlockFocus];

	*dragImageOffset = NSMakePoint(rect.size.width / 2 + 10, 0);
	return newImage;

}


#pragma mark Row highlighting

- (NSColor *)searchResultHighlightColorForRow:(NSInteger)rowIndex
{
	// if the row is selected use default colors
	if ([self isRowSelected:rowIndex]) {
		if ([[self window] isKeyWindow]) {
			if ([[self window] firstResponder] == self) {
				return [NSColor alternateSelectedControlColor];
			}
			return [NSColor selectedControlColor];
		}
		return [NSColor secondarySelectedControlColor];
	}

	// light blue color highlighting search results
	return [NSColor colorWithCalibratedRed:0.751f green:0.831f blue:0.943f alpha:0.800f];
}

- (NSColor *)searchResultHighlightStrokeColorForRow:(NSInteger)rowIndex
{
	if ([self isRowSelected:rowIndex])
		return [NSColor colorWithCalibratedWhite:0.0f alpha:0.30f];

	return [NSColor colorWithCalibratedWhite:0.0f alpha:0.05f];
}

- (void)drawRow:(NSInteger)rowIndex clipRect:(NSRect)tableViewClipRect
{
	NSRect rowRect = [self rectOfRow:rowIndex];
	BOOL isRowVisible = NSIntersectsRect(rowRect, tableViewClipRect);

	// draw special highlighting if the row is part of search results
	if (isRowVisible && [_historySearchController isRowInSearchResults:rowIndex]) 
    {
		NSRect highlightRect = NSInsetRect(rowRect, 1.0f, 1.0f);
		float radius = highlightRect.size.height / 2.0f;

		NSBezierPath *highlightPath = [NSBezierPath bezierPathWithRoundedRect:highlightRect xRadius:radius yRadius:radius];

		[[self searchResultHighlightColorForRow:rowIndex] set];
		[highlightPath fill];

		[[self searchResultHighlightStrokeColorForRow:rowIndex] set];
		[highlightPath stroke];
	}

	// draws the content inside the row
	[super drawRow:rowIndex clipRect:tableViewClipRect];
}

- (void)highlightSelectionInClipRect:(NSRect)tableViewClipRect
{
	// disable highlighting if the selected row is part of search results
	// instead do the highlighting in drawRow:clipRect: above
	if ([_historySearchController isRowInSearchResults:[self selectedRow]])
		return;

	[super highlightSelectionInClipRect:tableViewClipRect];
}

- (void)dealloc
{
    [_webView release];
    [_webHistoryController release];
    [_gitHistoryController release];
    [_historySearchController release];
    
    [super dealloc];
}
@end
