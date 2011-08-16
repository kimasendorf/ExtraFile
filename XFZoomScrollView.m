//
//  XFZoomScrollView.m
//  ExtraFile
//
//  Created by Kim Asendorf on 16.05.11.
//

#import "XFZoomScrollView.h"


NSString* XFZoomScrollViewFactor = @"factor";

static NSString* const XFZoomScrollViewLabels[] = {@"10%", @"25%", @"50%", @"75%", @"100%", @"125%", @"150%", @"200%", @"400%", @"800%", @"1600%", @"3200%", @"6400%"};
static const CGFloat XFZoomScrollViewFactors[] = {0.1f, 0.25f, 0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 2.0f, 4.0f, 8.0f, 16.0f, 32.0f, 64.0f};
static const NSInteger XFZoomScrollViewPopUpButtonItemCount = sizeof(XFZoomScrollViewLabels) / sizeof(NSString *);


@implementation XFZoomScrollView

- (void)validateFactorPopUpButton
{
	if (!xfFactorPopUpButton) {
		xfFactorPopUpButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
		NSPopUpButtonCell* factorPopUpButtonCell = [xfFactorPopUpButton cell];
		[factorPopUpButtonCell setArrowPosition:NSPopUpArrowAtBottom];
		[factorPopUpButtonCell setBezelStyle:NSShadowlessSquareBezelStyle];
		[xfFactorPopUpButton setFont:[NSFont systemFontOfSize:[NSFont smallSystemFontSize]]];
		
		int i;
		for (i=0; i<XFZoomScrollViewPopUpButtonItemCount; i++) {
			[xfFactorPopUpButton addItemWithTitle:NSLocalizedStringFromTable(XFZoomScrollViewLabels[i], @"XFZoomScrollView", nil)];
			[[xfFactorPopUpButton itemAtIndex:i] setRepresentedObject:[NSNumber numberWithDouble:XFZoomScrollViewFactors[i]]];
		}
		
		[xfFactorPopUpButton sizeToFit];
		
		[self addSubview:xfFactorPopUpButton];
		[xfFactorPopUpButton release];
	}
}


- (void)zoomIn
{
	int index = [xfFactorPopUpButton indexOfSelectedItem];
	if (index < XFZoomScrollViewPopUpButtonItemCount-1) {
		index++;
		[xfFactorPopUpButton selectItemAtIndex:index];
		CGFloat factor = XFZoomScrollViewFactors[index];
		[self setFactor:factor];
	}
}


- (void)zoomOut
{
	int index = [xfFactorPopUpButton indexOfSelectedItem];
	if (index > 0) {
		index--;
		[xfFactorPopUpButton selectItemAtIndex:index];
		CGFloat factor = XFZoomScrollViewFactors[index];
		[self setFactor:factor];
	}
}


#pragma mark Bindings

- (void)setFactor:(CGFloat)factor
{
	_factor = factor;
	NSView* clipView = [[self documentView] superview];
	NSSize clipViewFrameSize = [clipView frame].size;
	[clipView setBoundsSize:NSMakeSize((clipViewFrameSize.width / _factor), (clipViewFrameSize.height / _factor))];
}


- (void)bind:(NSString *)binding toObject:(id)observableObject withKeyPath:(NSString *)observableKeyPath options:(NSDictionary *)options
{
	if ([binding isEqualToString:XFZoomScrollViewFactor]) {
		[self validateFactorPopUpButton];
		[xfFactorPopUpButton bind:NSSelectedObjectBinding toObject:observableObject withKeyPath:observableKeyPath options:options];
	}
	[super bind:binding toObject:observableObject withKeyPath:observableKeyPath options:options];
}


- (void)unbind:(NSString *)binding
{
	[super unbind:binding];
	if ([binding isEqualToString:XFZoomScrollViewFactor]) {
		[xfFactorPopUpButton unbind:NSSelectedObjectBinding];
	}
}


#pragma mark Custom Look

- (void)tile
{
	NSAssert([self hasHorizontalScroller], @"XFZoomScrollView doesn't support use without a horizontal scrollbar.");
	
	[super tile];
	NSScroller* horizontalScroller = [self horizontalScroller];
	NSRect horizontalScrollerFrame = [horizontalScroller frame];
	
	[self validateFactorPopUpButton];
	NSRect factorPopUpButtonFrame = [xfFactorPopUpButton frame];
	factorPopUpButtonFrame.origin.x = horizontalScrollerFrame.origin.x;
	factorPopUpButtonFrame.origin.y = horizontalScrollerFrame.origin.y;
	factorPopUpButtonFrame.size.height = horizontalScrollerFrame.size.height;
	[xfFactorPopUpButton setFrame:factorPopUpButtonFrame];
	
	horizontalScrollerFrame.origin.x += factorPopUpButtonFrame.size.width;
	horizontalScrollerFrame.size.width -= factorPopUpButtonFrame.size.width;
	[horizontalScroller setFrame:horizontalScrollerFrame];
}

@end
