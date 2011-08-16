//
//  XFProfile.h
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import <Cocoa/Cocoa.h>


@interface XFProfile : NSObject
{
	CMProfileRef		xfRef;
    CGColorSpaceRef		xfColorspace;
    CMProfileLocation	xfLocation;
    OSType				xfClass;
    OSType				xfSpace;
    NSString*			xfName;
    NSString*			xfPath;
}

+ (NSArray *)arrayOfAllProfiles;
+ (NSArray *)arrayOfAllProfilesWithSpace:(OSType)space;

+ (XFProfile *)profileDefaultRGB;
+ (XFProfile *)profileDefaultGray;
+ (XFProfile *)profileDefaultCMYK;

+ (XFProfile *)profileWithIterateData:(CMProfileIterateData *)data;
- (XFProfile *)initWithIterateData:(CMProfileIterateData *)data;
+ (XFProfile *)profileWithPath:(NSString *)path;
- (XFProfile *)initWithPath:(NSString *)path;
+ (XFProfile *)profileWithGenericRGB;
- (XFProfile *)initWithGenericRGB;
+ (XFProfile *)profileWithLinearRGB;
- (XFProfile *)initWithLinearRGB;

- (CMProfileRef)ref;
- (CMProfileLocation *)location;
- (OSType)classType;
- (OSType)spaceType;
- (NSString*) path;
- (CGColorSpaceRef)colorspace;

- (NSData*)dataForCISoftproofTextureWithGridSize:(size_t)grid;

@end

CGImageRef CGImageCreateCopyWithDefaultSpace(CGImageRef image);
