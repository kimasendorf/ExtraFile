//
//  XFImageFilter.h
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#import "XFProfile.h"


@interface XFImageFilter : NSObject
{
	CGImageRef		xfImage;
    CIImage*		xfCIImage;
	
    XFProfile*		xfProfile;
    CIFilter*		xfCIExposure;
    CIFilter*		xfCIColorControls;
    CIFilter*		xfCIColorCube;
}

- (id)initWithImage:(CGImageRef)image;
- (void)setProfile:(XFProfile *)profile;
- (void)setExposure:(NSNumber *)exposure;
- (void)setSaturation:(NSNumber *)saturation;

- (CIImage *)imageWithTransform:(CGAffineTransform)ctm;
- (CGImageRef)createCGImage;

@end
