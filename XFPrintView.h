//
//  XFPrintView.h
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import <Cocoa/Cocoa.h>


@class XFImageDocument;

@interface XFPrintView : NSView
{
	XFImageDocument* xfImageDoc;
}

- (id)initWithFrame:(NSRect)frame document:(XFImageDocument*)imageDoc;

@end
