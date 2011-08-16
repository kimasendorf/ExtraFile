//
//  XFImageFilter.m
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import "XFImageFilter.h"


@implementation XFImageFilter

- (void)dealloc
{
    CGImageRelease(xfImage);
    [xfCIImage release];
    [xfProfile release];
    [xfCIExposure release];
    [xfCIColorControls release];
    [xfCIColorCube release];
	
    [super dealloc];
}


- (id)initWithImage:(CGImageRef)image
{
    if ((self = [super init]))
    {
        xfImage = CGImageRetain(image);
        xfCIImage = [[CIImage imageWithCGImage:xfImage] retain];
    }
    return self;
}


- (void)setProfile:(XFProfile *)profile
{
    [xfProfile release];
    xfProfile = [profile retain];
	
    if (xfProfile == nil)
    {
        [xfCIColorCube autorelease];
        xfCIColorCube = nil;
    }
    else
    {
        // Use the CIColorCube filter three-dimensional color table 
        // to transform the source image pixels
        if (xfCIColorCube == nil)
            xfCIColorCube = [[CIFilter filterWithName: @"CIColorCube"] retain];
        
        // Get the transformed data
        static const int kSoftProofGrid = 32;
        NSData *data = [xfProfile dataForCISoftproofTextureWithGridSize:kSoftProofGrid];
        
        [xfCIColorCube setValue:data
						forKey:@"inputCubeData"];
        [xfCIColorCube setValue:[NSNumber numberWithInt:kSoftProofGrid]
						forKey:@"inputCubeDimension"];
    }
}


- (void)setExposure:(NSNumber *)exposure
{
    if (xfCIExposure == nil)
        xfCIExposure = [[CIFilter filterWithName: @"CIExposureAdjust"] retain];
	
    [xfCIExposure setValue:exposure
				   forKey: @"inputEV"];
}


- (void)setSaturation:(NSNumber *)saturation
{
    if (xfCIColorControls == nil)
        xfCIColorControls = [[CIFilter filterWithName: @"CIColorControls"] retain];
	
    [xfCIColorControls setValue:saturation
						forKey: @"inputSaturation"];
	
    [xfCIColorControls setValue:[[[xfCIColorControls attributes]
								 objectForKey: @"inputBrightness"]
								objectForKey: @"CIAttributeIdentity"]
						forKey: @"inputBrightness"];
	
    [xfCIColorControls setValue:[[[xfCIColorControls attributes]
								 objectForKey: @"inputContrast"]
								objectForKey: @"CIAttributeIdentity"]
						forKey: @"inputContrast"];
}


- (CIImage *)imageWithTransform:(CGAffineTransform)ctm
{
    // Returns a new image representing the original image with the transform
    // 'ctm' appended to it.
    CIImage* ciimg = [xfCIImage imageByApplyingTransform:ctm];
	
    if (xfCIExposure)
    {
        [xfCIExposure setValue:ciimg forKey:@"inputImage"];
        ciimg = [xfCIExposure valueForKey: @"outputImage"];
    }
	
    if (xfCIColorControls)
    {
        [xfCIColorControls setValue:ciimg forKey:@"inputImage"];
        ciimg = [xfCIColorControls valueForKey: @"outputImage"];
    }
	
    if (xfCIColorCube)
    {
        [xfCIColorCube setValue:ciimg forKey: @"inputImage"];
        ciimg = [xfCIColorCube valueForKey: @"outputImage"];
    }
	
    return ciimg;
}


- (CGImageRef)createCGImage
{
    if (xfImage==nil)
        return nil;
	
    XFProfile* prof = xfProfile;
    if (xfProfile==nil)
        prof = [XFProfile profileWithGenericRGB];
	
    // calculate bits per pixel and row bytes and alphaInfo
    size_t height = CGImageGetHeight(xfImage);
    size_t width = CGImageGetWidth(xfImage);
    CGRect rect = {{0,0}, {width, height}};
    size_t bitsPerComponent = 8;
    size_t bytesPerRow = 0;
    CGImageAlphaInfo alphaInfo = kCGImageAlphaNone;
	
    switch ([prof spaceType])
    {
        case cmGrayData:
            bytesPerRow = width;
            alphaInfo = kCGImageAlphaNone; /* RGB. */
            break;
        case cmRGBData:
            bytesPerRow = width*4;
            alphaInfo = kCGImageAlphaPremultipliedLast; /* premultiplied RGBA */
            break;
        case cmCMYKData:
            bytesPerRow = width*4;
            alphaInfo = kCGImageAlphaNone; /* RGB. */
            break;
        default:
            return nil;
            break;
    }
	
    CGContextRef context = CGBitmapContextCreate(nil, width, height,
												 bitsPerComponent, bytesPerRow,
												 [prof colorspace], alphaInfo);
	
    CIContext* cicontext = [CIContext contextWithCGContext: context options: nil];
	
    // If context doesn't support alpha then first fill it with white.
    // That is most likely to be desireable.
    if (alphaInfo == kCGImageAlphaNone)
    {
        CGColorSpaceRef graySpace = CGColorSpaceCreateDeviceGray();
        const CGFloat whiteComps[2] = {1.0, 1.0};
        CGColorRef whiteColor = CGColorCreate(graySpace, whiteComps);
        CFRelease(graySpace);
        CGContextSetFillColorWithColor(context, whiteColor);
        CGContextFillRect(context, rect);
        CFRelease(whiteColor);
    }
	
    CIImage* ciimg = xfCIImage;
	
    // exposure adjustment
    if (xfCIExposure)
    {
        [xfCIExposure setValue:ciimg forKey:@"inputImage"];
        ciimg = [xfCIExposure valueForKey: @"outputImage"];
    }
	
    // three-dimensional color table adjustment
    if (xfCIColorControls)
    {
        [xfCIColorControls setValue:ciimg forKey:@"inputImage"];
        ciimg = [xfCIColorControls valueForKey: @"outputImage"];
    }
	
	
    CGRect extent = [ciimg extent];
	
    [cicontext drawImage: ciimg inRect:rect fromRect:extent];
	
    CGImageRef image = CGBitmapContextCreateImage(context);
	
    CGContextRelease(context);
	
    return image;
}

@end
