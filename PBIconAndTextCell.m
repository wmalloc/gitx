//
//  PBIconAndTextCell.m
//  GitX
//
//  Created by Ciarán Walsh on 23/09/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//
// Adopted from http://www.cocoadev.com/index.pl?NSTableViewImagesAndText

#import "PBIconAndTextCell.h"


@implementation PBIconAndTextCell
@synthesize image = _image;

- (void)dealloc
{
    [_image release];

	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	PBIconAndTextCell *cell = [super copyWithZone:zone];
	cell.image              = _image;
	return cell;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if (_image)
    {
		NSSize  imageSize;
		NSRect  imageFrame;

		imageSize = [_image size];
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
		if ([self drawsBackground]) {
			[[self backgroundColor] set];
			NSRectFill(imageFrame);
		}
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;

		if ([controlView isFlipped])
			imageFrame.origin.y += floor((cellFrame.size.height + imageFrame.size.height) / 2);
		else
			imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);

		[_image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize
{
	NSSize cellSize = [super cellSize];
	cellSize.width += (_image ? [_image size].width : 0) + 3;
	return cellSize;
}

@end
