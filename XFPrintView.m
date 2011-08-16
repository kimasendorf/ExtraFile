//
//  XFPrintView.m
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import "XFPrintView.h"
#import "XFImageDocument.h"


@implementation XFPrintView

- (id)initWithFrame:(NSRect)frame document:(XFImageDocument*)imageDoc{
    self = [super initWithFrame:frame];
    if (self) {
        xfImageDoc = [imageDoc retain];
    }
    return self;
}


- (void)dealloc
{
    [xfImageDoc release];
    [super dealloc];
}


- (NSString*)printJobTitle
{
    return [xfImageDoc displayName];
}


- (void)drawRect:(NSRect)dirtyRect
{
    CGImageRef image = [xfImageDoc currentCGImage];
	
    if (image)
    {
        CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
		
        CGContextSaveGState(context);
		
        float scale, xScale, yScale;
		
        CGSize  imageSize;
        NSRect  printableRect = NSIntegralRect([self frame]);
		
        CGRect  imageRect = {{0,0}, {CGImageGetWidth(image), CGImageGetHeight(image)}};
		
        CGAffineTransform imTransform = [xfImageDoc imageTransform];
		
        imageSize = CGRectApplyAffineTransform(imageRect, imTransform).size;
		
        xScale = printableRect.size.width  / imageSize.width;
        yScale = printableRect.size.height / imageSize.height;
        scale = MIN(xScale, yScale);
		
        imTransform = CGAffineTransformConcat(imTransform, CGAffineTransformMakeScale(scale,scale));
        
        float tx = (printableRect.size.width - imageSize.width * scale)  / 2.
		+ printableRect.origin.x;
        float ty = (printableRect.size.height - imageSize.height* scale) / 2.
		+ printableRect.origin.y;
		
        imTransform.tx += tx;
        imTransform.ty += ty;
		
        // adjust transform
        CGContextConcatCTM(context, imTransform);
        
        // draw!
        CGContextDrawImage (context, imageRect, image);
        
        CGContextRestoreGState(context);
        
        CGImageRelease(image);
    }
}

@end
