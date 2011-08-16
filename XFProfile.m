//
//  XFProfile.m
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import "XFProfile.h"


static OSErr profileIterate(CMProfileIterateData *info, void *refCon)
{
    NSMutableArray* array = (NSMutableArray*)refCon;
	
    XFProfile* prof = [XFProfile profileWithIterateData:info];
    if (prof)
        [array addObject:prof];
	
    return noErr;
}


@implementation XFProfile

+ (NSArray*)arrayOfAllProfilesWithSpace:(OSType)space
{
    CFIndex  i, count;
    NSArray* profArray = [XFProfile arrayOfAllProfiles];
    NSMutableArray* profs = [NSMutableArray arrayWithCapacity:0];
	
    count = [profArray count];
    for (i=0; i<count; i++)
    {
        XFProfile* prof = (XFProfile*)[profArray objectAtIndex:i];
        OSType  pClass = [prof classType];
        
        if ([prof spaceType]==space && [prof description] && 
            (pClass==cmDisplayClass || pClass==cmOutputClass))
            [profs addObject:prof];
    }
	
    [profArray release];
    return profs;
}


+ (NSArray *)arrayOfAllProfiles
{
    NSMutableArray* profs = [[NSMutableArray arrayWithCapacity:0] retain];
    
    CMProfileIterateUPP iterUPP = NewCMProfileIterateUPP(profileIterate);
    CMIterateColorSyncFolder(iterUPP, NULL, 0L, profs);
    DisposeCMProfileIterateUPP(iterUPP);
	
    return (NSArray*)profs;
}


+ (XFProfile *)profileDefaultRGB
{
    NSString* path = [[[NSUserDefaultsController sharedUserDefaultsController] defaults]
					  objectForKey:@"DefaultRGBProfile"];
    return [XFProfile profileWithPath:path];
}


+ (XFProfile *)profileDefaultGray
{
    NSString* path = [[[NSUserDefaultsController sharedUserDefaultsController] defaults]
					  objectForKey:@"DefaultGrayProfile"];
    return [XFProfile profileWithPath:path];
}


+ (XFProfile *)profileDefaultCMYK
{
    NSString* path = [[[NSUserDefaultsController sharedUserDefaultsController] defaults]
					  objectForKey:@"DefaultCMYKProfile"];
    return [XFProfile profileWithPath:path];
}


+ (XFProfile *)profileWithGenericRGB
{
    return [[[XFProfile alloc] initWithGenericRGB] autorelease];
}


+ (XFProfile *)profileWithLinearRGB
{
    return [[[XFProfile alloc] initWithLinearRGB] autorelease];
}


+ (XFProfile *)profileWithIterateData:(CMProfileIterateData *)data
{
    return [[[XFProfile alloc] initWithIterateData:data] autorelease];
}


+ (XFProfile *)profileWithPath:(NSString *)path
{
    return [[[XFProfile alloc] initWithPath:path] autorelease];
}


- (XFProfile *)initWithGenericRGB
{
    xfLocation.locType  = cmPathBasedProfile;
    strcpy(xfLocation.u.pathLoc.path, "/System/Library/ColorSync/Profiles/Generic RGB Profile.icc");
    xfClass = cmDisplayClass;
    xfSpace = cmRGBData;
	
    if (CMOpenProfile(&xfRef, &xfLocation) == noErr)
    {
        return self;
    }
    else
    {
        [self autorelease];
        return nil;
    }
}


- (XFProfile *)initWithLinearRGB
{
    static const UInt8 data[0x220] = 
	"\x00\x00\x02\x20\x61\x70\x70\x6c\x02\x20\x00\x00\x6d\x6e\x74\x72"
	"\x52\x47\x42\x20\x58\x59\x5a\x20\x07\xd2\x00\x05\x00\x0d\x00\x0c"
	"\x00\x00\x00\x00\x61\x63\x73\x70\x41\x50\x50\x4c\x00\x00\x00\x00"
	"\x61\x70\x70\x6c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	"\x00\x00\x00\x00\x00\x00\xf6\xd6\x00\x01\x00\x00\x00\x00\xd3\x2d"
	"\x61\x70\x70\x6c\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	"\x00\x00\x00\x0a\x72\x58\x59\x5a\x00\x00\x00\xfc\x00\x00\x00\x14"
	"\x67\x58\x59\x5a\x00\x00\x01\x10\x00\x00\x00\x14\x62\x58\x59\x5a"
	"\x00\x00\x01\x24\x00\x00\x00\x14\x77\x74\x70\x74\x00\x00\x01\x38"
	"\x00\x00\x00\x14\x63\x68\x61\x64\x00\x00\x01\x4c\x00\x00\x00\x2c"
	"\x72\x54\x52\x43\x00\x00\x01\x78\x00\x00\x00\x0e\x67\x54\x52\x43"
	"\x00\x00\x01\x78\x00\x00\x00\x0e\x62\x54\x52\x43\x00\x00\x01\x78"
	"\x00\x00\x00\x0e\x64\x65\x73\x63\x00\x00\x01\xb0\x00\x00\x00\x6d"
	"\x63\x70\x72\x74\x00\x00\x01\x88\x00\x00\x00\x26\x58\x59\x5a\x20"
	"\x00\x00\x00\x00\x00\x00\x74\x4b\x00\x00\x3e\x1d\x00\x00\x03\xcb"
	"\x58\x59\x5a\x20\x00\x00\x00\x00\x00\x00\x5a\x73\x00\x00\xac\xa6"
	"\x00\x00\x17\x26\x58\x59\x5a\x20\x00\x00\x00\x00\x00\x00\x28\x18"
	"\x00\x00\x15\x57\x00\x00\xb8\x33\x58\x59\x5a\x20\x00\x00\x00\x00"
	"\x00\x00\xf3\x52\x00\x01\x00\x00\x00\x01\x16\xcf\x73\x66\x33\x32"
	"\x00\x00\x00\x00\x00\x01\x0c\x42\x00\x00\x05\xde\xff\xff\xf3\x26"
	"\x00\x00\x07\x92\x00\x00\xfd\x91\xff\xff\xfb\xa2\xff\xff\xfd\xa3"
	"\x00\x00\x03\xdc\x00\x00\xc0\x6c\x63\x75\x72\x76\x00\x00\x00\x00"
	"\x00\x00\x00\x01\x01\x00\x00\x00\x74\x65\x78\x74\x00\x00\x00\x00"
	"\x43\x6f\x70\x79\x72\x69\x67\x68\x74\x20\x41\x70\x70\x6c\x65\x20"
	"\x43\x6f\x6d\x70\x75\x74\x65\x72\x20\x49\x6e\x63\x2e\x00\x00\x00"
	"\x64\x65\x73\x63\x00\x00\x00\x00\x00\x00\x00\x13\x4c\x69\x6e\x65"
	"\x61\x72\x20\x52\x47\x42\x20\x50\x72\x6f\x66\x69\x6c\x65\x00\x00"
	"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
	"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
	
    xfLocation.locType  = cmBufferBasedProfile;
    xfLocation.u.bufferLoc.buffer = (void*)data;
    xfLocation.u.bufferLoc.size = 0x220;
    xfClass = cmDisplayClass;
    xfSpace = cmRGBData;
	
    if (CMOpenProfile(&xfRef, &xfLocation) == noErr)
    {
        return self;
    }
    else
    {
        [self autorelease];
        return nil;
    }
}


- (XFProfile *)initWithIterateData:(CMProfileIterateData *)info
{
    const size_t kMaxProfNameLen = 36;
	
    xfLocation  = info->location;
    xfClass = info->header.profileClass;
    xfSpace = info->header.dataColorSpace;
	
    if (info->uniCodeNameCount > 1)
    {
        CFIndex numChars = info->uniCodeNameCount - 1;
        if (numChars > kMaxProfNameLen)
            numChars = kMaxProfNameLen;
        xfName = [[NSString stringWithCharacters:info->uniCodeName length:numChars] retain];
    }
	
    return self;
}


- (XFProfile *)initWithPath:(NSString *)path
{
    if (path)
    {
        xfPath = [path retain];
        
        xfLocation.locType = cmPathBasedProfile;
        strncpy(xfLocation.u.pathLoc.path, [path fileSystemRepresentation], 255);
        
        CMAppleProfileHeader header;
        if (noErr==CMGetProfileHeader([self ref], &header))
        {
            xfClass = header.cm2.profileClass;
            xfSpace = header.cm2.dataColorSpace;
        }
        else
        {
            [self autorelease];
            return nil;
        }
    }
	
    return self;
}


- (void)dealloc
{
    CMCloseProfile(xfRef);
    CGColorSpaceRelease(xfColorspace);
    [xfName release];
    [xfPath release];
    [super dealloc];
}


- (CMProfileRef)ref
{
    if (xfRef == NULL)
        (void) CMOpenProfile(&xfRef, &xfLocation);
	
    return xfRef;
}


- (CMProfileLocation *)location
{
	return &xfLocation;
}


- (OSType)classType
{
    return xfClass;
}


- (OSType)spaceType
{
    return xfSpace;
}


- (NSString *)description
{
    if (xfName == nil)
        CMCopyProfileDescriptionString([self ref], (CFStringRef *) &xfName);
	
    return xfName;
}


- (NSString *)path
{
    if (xfPath == nil)
    {
		/*
		if (xfLocation.locType == cmFileBasedProfile)
        {
            FSRef       fsref;
            UInt8       path[1024];
            if (FSpMakeFSRef(&(mLocation.u.fileLoc.spec), &fsref) == noErr &&
                FSRefMakePath(&fsref, path, 1024) == noErr)
                xfPath = [[NSString stringWithUTF8String:(const char *)path] retain];
        }
        else
		 */
		if (xfLocation.locType == cmPathBasedProfile)
        {
            xfPath = [[NSString stringWithUTF8String:xfLocation.u.pathLoc.path] retain];
        }
    }
	
    return xfPath;
}


- (BOOL)isEqual:(id)obj
{
    if ([obj isKindOfClass:[self class]])
        return [[self path] isEqualToString:[obj path]];
    return [super isEqual:obj];
}


- (CGColorSpaceRef)colorspace
{
    if (xfColorspace == nil)
        xfColorspace = CGColorSpaceCreateWithPlatformColorSpace([self ref]);
    return xfColorspace;
}


- (NSData *)dataForCISoftproofTextureWithGridSize:(size_t) grid
{
    NSData*				nsdata = nil;
    NCMConcatProfileSet* set = nil;
    size_t				count = (grid*grid*grid) * 4;
    size_t              size;
    UInt8*				data8 = nil;
    CMWorldRef			cw = nil;
    CMProfileRef		displayProf = nil;
    XFProfile*			linRGB = nil;
	
    // profile for transform
    linRGB = [XFProfile profileWithLinearRGB];
    if (linRGB == nil)
        goto bail;
	
    // specify size of resulting data
    size = count * sizeof(float);
    nsdata = [NSMutableData dataWithLength:size];
    if (nsdata == nil)
        goto bail;
	
    // now build our color world transform
    size = offsetof(NCMConcatProfileSet, profileSpecs[3]);
    set = (NCMConcatProfileSet *) calloc(1, size);
    if (set==nil)
        goto bail;
	
    set->cmm = 0000;
    set->flagsMask = 0xFFFFFFFF;
    set->profileCount  = 3;
    set->flags = (cmBestMode) << 16 | cmGamutCheckingMask;
	
    set->profileSpecs[0].profile = [linRGB ref];
    set->profileSpecs[1].profile = [self ref];
    set->profileSpecs[2].profile = [linRGB ref];
	
    set->profileSpecs[0].renderingIntent = kUseProfileIntent;
    set->profileSpecs[1].renderingIntent = kUseProfileIntent;
    set->profileSpecs[2].renderingIntent = kUseProfileIntent;
	
    set->profileSpecs[0].transformTag = kDeviceToPCS;
    set->profileSpecs[1].transformTag = kPCSToPCS;
    set->profileSpecs[2].transformTag = kPCSToDevice;
	
    // Define a color world for color transformations among concatenated profiles.
    if (NCWConcatColorWorld (&cw, set, nil, nil) != noErr)
        goto bail;
	
    size = count * sizeof(UInt8);
    data8 = malloc(size);
	
    	
    //  cmTextureRGBtoRGBX8 = RGB to 8-bit RGBx texture
	
    if (CWFillLookupTexture (cw, grid, cmTextureRGBtoRGBX8, size, data8) != noErr)
        goto bail;
	
    float* dataPtr = (float*) [(NSMutableData *)nsdata mutableBytes];
    if (dataPtr == nil)
        goto bail;
	
    size_t i;
    for (i=0; i<count; i++)
        dataPtr[i] = (float)data8[i]/255.0;
	
bail:
	
    if (data8) free(data8);
    if (displayProf) CMCloseProfile (displayProf);
    if (cw) CWDisposeColorWorld(cw);
    if (set) free(set);
    return nsdata;
}

@end


//DEFAULT PROFILE
CGImageRef CGImageCreateCopyWithDefaultSpace(CGImageRef image)
{
    if (image == nil)
        return nil;
    
    CGImageRef newImage = nil;
	
    XFProfile* dfltRGB = [XFProfile profileDefaultRGB];
    XFProfile* dfltGray = [XFProfile profileDefaultGray];
    XFProfile* dfltCMYK = [XFProfile profileDefaultCMYK];
	
    CGColorSpaceRef devRGB = CGColorSpaceCreateDeviceRGB();
    CGColorSpaceRef devGray = CGColorSpaceCreateDeviceGray();
    CGColorSpaceRef devCMYK = CGColorSpaceCreateDeviceCMYK();
	
    if (dfltRGB && CFEqual(devRGB,CGImageGetColorSpace(image)))
        newImage = CGImageCreateCopyWithColorSpace(image, [dfltRGB colorspace]);
    if (dfltGray && CFEqual(devGray,CGImageGetColorSpace(image)))
        newImage = CGImageCreateCopyWithColorSpace(image, [dfltGray colorspace]);
    if (dfltCMYK && CFEqual(devCMYK,CGImageGetColorSpace(image)))
        newImage = CGImageCreateCopyWithColorSpace(image, [dfltCMYK colorspace]);
	
    if (newImage == nil)
        newImage = CGImageRetain(image);
	
    CFRelease(devRGB);
    CFRelease(devGray);
    CFRelease(devCMYK);
	
    return newImage;
}
