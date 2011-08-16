//
//  XFImageView.h
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import <Quartz/Quartz.h>

#import "XFImageDocument.h"


@class XFImageDocument;

@interface XFImageView : NSView
{
	IBOutlet XFImageDocument* xfImageDoc;
	
	NSColor* backgroundColor;
}

- (void)changeBackgroundColor:(NSColor *)color;

- (NSData *)dataInXFF;
- (NSData *)dataInCCI;
- (NSData *)dataInMCF;
- (NSData *)dataIn4BC;
- (NSData *)dataInBASCII;
- (NSData *)dataInBLINX;
- (NSData *)dataInUSPEC;

@end
