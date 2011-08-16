//
//  XFZoomScrollView.h
//  ExtraFile
//
//  Created by Kim Asendorf on 16.05.11.
//

#import <Cocoa/Cocoa.h>


extern NSString* XFZoomScrollViewFactor;

@interface XFZoomScrollView : NSScrollView
{
	NSPopUpButton* xfFactorPopUpButton;
	CGFloat _factor;
}

- (void)setFactor:(CGFloat)factor;
- (void)zoomIn;
- (void)zoomOut;

@end
