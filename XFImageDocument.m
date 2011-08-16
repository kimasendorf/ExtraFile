//
//  XFImageDocument.m
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import "XFImageDocument.h"
#import "XFApp.h"
#import "XFPrintView.h"


#define BITOP(a,b,op) \
((a)[(size_t)(b)/(8*sizeof *(a))] op (size_t)1<<((size_t)(b)%(8*sizeof *(a))))

// BITOP(array, 40, |=); /* sets bit 40 */
// BITOP(array, 41, ^=); /* toggles bit 41 */
// if (BITOP(array, 42, &)) return 0; /* tests bit 42 */
// BITOP(array, 43, &=~); /* clears bit 43 */


static NSString* ImageIOLocalizedString(NSString* key)
{
    static NSBundle* b = nil;
    
    if (b==nil)
        b = [NSBundle bundleWithIdentifier:@"com.apple.ImageIO.framework"];
    
    return [b localizedStringForKey:key value:key table: @"CGImageSource"];
}


static NSString* XFAppString = @"EXTRAFILE";
static NSString* XFTypeNameRoot = @"org.extrafile";
static NSString* XFTypeNameXFF = @"org.extrafile.xff";
static NSString* XFTypeNameCCI = @"org.extrafile.cci";
static NSString* XFTypeNameMCF = @"org.extrafile.mcf";
static NSString* XFTypeName4BC = @"org.extrafile.4bc";
static NSString* XFTypeNameBASCII = @"org.extrafile.bascii";
static NSString* XFTypeNameBLINX = @"org.extrafile.blinx";
static NSString* XFTypeNameUSPEC = @"org.extrafile.uspec";


static NSString* XFIOLocalizedString(NSString* key)
{
	static NSString* type = nil;
	
	if ([key isEqualToString:XFTypeNameXFF]) {
		type = @"XFF";
	} else if ([key isEqualToString:XFTypeNameCCI]) {
		type = @"CCI";
	} else if ([key isEqualToString:XFTypeNameMCF]) {
		type = @"MCF";
	} else if ([key isEqualToString:XFTypeName4BC]) {
		type = @"4BC";
	} else if ([key isEqualToString:XFTypeNameBASCII]) {
		type = @"BASCII";
	} else if ([key isEqualToString:XFTypeNameBLINX]) {
		type = @"BLINX";
	} else if ([key isEqualToString:XFTypeNameUSPEC]) {
		type = @"USPEC";
	}
    return type;
}


static NSString* separatorString = @">data>";


@implementation XFImageDocument


- (id)init
{
    self = [super init];
    if (self) {
		_zoomFactor = 1.0f;
    }
    return self;
}


- (NSString *)windowNibName
{
    return @"XFImageDocument";
}


- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
	
    NSWindow* window = [self windowForSheet];
    [window setDelegate:self];
    [window setDisplaysWhenScreenProfileChanges:YES];
	
	automaticReload = [XFApp getAutomaticReload];
	cleanBuffer = [XFApp getCleanBuffer];
	[xfImageView changeBackgroundColor:[XFApp getBackgroundColor]];
	[xfZoomScrollView bind:XFZoomScrollViewFactor toObject:self withKeyPath:@"zoomFactor" options:nil];
    
    [self setupAll];
}


- (void)dealloc
{
    CGImageRelease(xfImage);
    if (xfMetadata) CFRelease(xfMetadata);
    
    [xfFilteredImage release];
    
    [xfExposureValue release];
    [xfSaturationValue release];
    [xfProfileValue release];
    
    [xfProfiles release];
	
    [xfSaveUTI release];
    if (xfSaveMetaAndOpts) CFRelease(xfSaveMetaAndOpts);
	
    [[self undoManager] removeAllActionsWithTarget: self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [super dealloc];
}


- (void)close
{
	[xfZoomScrollView unbind:XFZoomScrollViewFactor];
	[super close];
}


#pragma mark #### Getter

+ (NSArray *)readableTypes
{
	NSMutableArray* allTypes = [NSMutableArray arrayWithArray:[(NSArray *)CGImageSourceCopyTypeIdentifiers() autorelease]];
	
	//ADD CUSTOM FORMATS
	[allTypes addObject:XFTypeNameXFF];
	[allTypes addObject:XFTypeNameCCI];
	[allTypes addObject:XFTypeNameMCF];
	[allTypes addObject:XFTypeName4BC];
	[allTypes addObject:XFTypeNameBASCII];
	[allTypes addObject:XFTypeNameBLINX];
	[allTypes addObject:XFTypeNameUSPEC];
	
    return allTypes;
}


+ (NSArray *)writableTypes
{	
	NSMutableArray* allTypes = [NSMutableArray arrayWithArray:[(NSArray *)CGImageDestinationCopyTypeIdentifiers() autorelease]];
	
	//ADD CUSTOM FORMATS
	[allTypes addObject:XFTypeNameXFF];
	[allTypes addObject:XFTypeNameCCI];
	[allTypes addObject:XFTypeNameMCF];
	[allTypes addObject:XFTypeName4BC];
	[allTypes addObject:XFTypeNameBASCII];
	[allTypes addObject:XFTypeNameBLINX];
	[allTypes addObject:XFTypeNameUSPEC];
	
	return allTypes;
}


+ (BOOL)isNativeType:(NSString *)type
{
    return [[self writableTypes] containsObject:type];
}


#pragma mark -

- (NSRect)visibleRect
{
	return [xfZoomScrollView documentVisibleRect];
}


#pragma mark #### Image Settings

- (NSArray *)profiles
{
    if (xfProfiles == nil)
    {
        NSArray* profArray = [XFProfile arrayOfAllProfiles];
        CFIndex i, count = [profArray count];
        NSMutableArray* profs = [NSMutableArray arrayWithCapacity:0];
        
        for (i=0; i<count; i++)
        {
            // check profile space and class
            XFProfile* prof = (XFProfile*)[profArray objectAtIndex:i];
            OSType pSpace = [prof spaceType];
            OSType pClass = [prof classType];
			
            // look only for image profiles with RGB, CMYK and Gray color spaces,
            // and only monitor and printer profiles
            if ((pSpace==cmRGBData || pSpace==cmCMYKData || pSpace==cmGrayData) && 
                (pClass==cmDisplayClass || pClass==cmOutputClass) && [prof description])
                [profs addObject:prof];
        }
		
        [profArray release];
        xfProfiles = [profs retain];
    }
    return xfProfiles;
}


// getter for image effects state (on or off)
- (BOOL)switchState
{
    return [xfSwitchValue boolValue];
}

- (NSNumber *)exposure
{
    return xfExposureValue;
}

- (NSNumber *)saturation
{
    return xfSaturationValue;
}

- (XFProfile *)profile
{
    return xfProfileValue;
}


// Keep track of image effects state
//  val parameter is TRUE if effects are turned on for the image
//  val parameter is FALSE if effects are turned off for the image
//
- (void)setSwitchState:(NSNumber *)val
{
    if (val == xfSwitchValue)
        return;
    
    if (xfSwitchValue)
    {
        [[self undoManager] registerUndoWithTarget:self selector:@selector(setSwitchState:) object:xfSwitchValue];
        [[self undoManager] setActionName:[xfSwitchValue intValue]?@"Disable Effects":@"Enable Effects"];
    }
    
    [xfSwitchValue release];
    xfSwitchValue = [val retain];
    [xfImageView setNeedsDisplay:YES];
}


// Setter for image exposure value
//
- (void)setExposure:(NSNumber *)val
{
    if (val == xfExposureValue)
        return;
    
    if (xfExposureValue)
    {
        [[self undoManager] registerUndoWithTarget:self selector:@selector(setExposure:) object:xfExposureValue];
        [[self undoManager] setActionName:@"Exposure"];
    }
	
    [xfExposureValue release];
    xfExposureValue = [val retain];
    [xfFilteredImage setExposure:xfExposureValue];
    [xfImageView setNeedsDisplay:YES];
}


// Setter for image saturation value
//
- (void)setSaturation:(NSNumber *)val
{
    if (val == xfSaturationValue)
        return;
    
    if (xfSaturationValue)
    {
        [[self undoManager] registerUndoWithTarget:self selector:@selector(setSaturation:) object:xfSaturationValue];
        [[self undoManager] setActionName:@"Saturation"];
    }
    
    [xfSaturationValue release];
    xfSaturationValue = [val retain];
    [xfFilteredImage setSaturation:xfSaturationValue];
    [xfImageView setNeedsDisplay:YES];
}


// Setter for image profile
//
- (void)setProfile:(XFProfile *)val
{
    if (val == xfProfileValue)
        return;
    
    if (xfProfileValue)
    {
        [[self undoManager] registerUndoWithTarget:self selector:@selector(setProfile:) object:xfProfileValue];
        [[self undoManager] setActionName:[[xfProfilePopup selectedItem] title]];
    }
    
    [xfProfileValue release];
    xfProfileValue = [val retain];
    [xfFilteredImage setProfile:xfProfileValue];
    [xfImageView setNeedsDisplay:YES];
}


// Initialization for image exposure slider
//
- (void)setupExposure
{
    CIFilter*      filter = [CIFilter filterWithName: @"CIExposureAdjust"];
    NSDictionary*  input = [[filter attributes] objectForKey: @"inputEV"];
    
    [xfExposureSlider setMinValue: [[input objectForKey: @"CIAttributeSliderMin"] floatValue]/4.0];
    [xfExposureSlider setMaxValue: [[input objectForKey: @"CIAttributeSliderMax"] floatValue]/4.0];
	
    [self setExposure:[input objectForKey: @"CIAttributeIdentity"]];
}


// Initialization for image saturation slider
//
- (void)setupSaturation
{
    CIFilter*      filter = [CIFilter filterWithName: @"CIColorControls"];
    NSDictionary*  input = [[filter attributes] objectForKey: @"inputSaturation"];
    
    [xfSaturationSlider setMinValue: [[input objectForKey: @"CIAttributeSliderMin"] floatValue]];
    [xfSaturationSlider setMaxValue: [[input objectForKey: @"CIAttributeSliderMax"] floatValue]];
    
    [self setSaturation:[input objectForKey: @"CIAttributeIdentity"]];
}


- (void)setupAll
{
    // Reset the sliders et. al.
    [self setSwitchState:[NSNumber numberWithBool:FALSE]];
    [self setupExposure];
    [self setupSaturation];
    [self setProfile:[XFProfile profileWithGenericRGB]];
    
    // Un-dirty the file and remove any undo state
    [self updateChangeCount:NSChangeCleared];
    [[self undoManager] removeAllActions];
}


#pragma mark #### Image Properties

- (float)dpiWidth
{
    NSNumber* val = [(NSDictionary *)xfMetadata objectForKey:(id)kCGImagePropertyDPIWidth];
    float  f = [val floatValue];
    return (f==0 ? 72 : f); // return default 72 if none specified
}


- (float)dpiHeight
{
    NSNumber* val = [(NSDictionary *)xfMetadata objectForKey:(id)kCGImagePropertyDPIHeight];
    float  f = [val floatValue];
    return (f==0 ? 72 : f); // return default 72 if none specified
}


- (int)orientation
{
    NSNumber* val = [(NSDictionary *)xfMetadata objectForKey:(id)kCGImagePropertyOrientation];
    int orient = [val intValue];
    if (orient<1 || orient>8)
        orient = 1;
    return orient;
}


- (CGAffineTransform)imageTransform
{
    float xdpi = [self dpiWidth];
    float ydpi = [self dpiHeight];
    int orient = [self orientation];
    
    float x = (ydpi>xdpi) ? ydpi/xdpi : 1;
    float y = (xdpi>ydpi) ? xdpi/ydpi : 1;
	float w = x * CGImageGetWidth(xfImage);
    float h = y * CGImageGetHeight(xfImage);
    
    CGAffineTransform ctms[8] = {
        { x, 0, 0, y, 0, 0},  //  1 =  row 0 top, col 0 lhs  =  normal
        {-x, 0, 0, y, w, 0},  //  2 =  row 0 top, col 0 rhs  =  flip horizontal
        {-x, 0, 0,-y, w, h},  //  3 =  row 0 bot, col 0 rhs  =  rotate 180
        { x, 0, 0,-y, 0, h},  //  4 =  row 0 bot, col 0 lhs  =  flip vertical
        { 0,-x,-y, 0, h, w},  //  5 =  row 0 lhs, col 0 top  =  rot -90, flip vert
        { 0,-x, y, 0, 0, w},  //  6 =  row 0 rhs, col 0 top  =  rot 90
        { 0, x, y, 0, 0, 0},  //  7 =  row 0 rhs, col 0 bot  =  rot 90, flip vert
        { 0, x,-y, 0, h, 0}   //  8 =  row 0 lhs, col 0 bot  =  rotate -90
    };
	
	//return ctms[orient-1];
    return ctms[orient+2];
}


- (CIImage *)currentCIImageWithTransform:(CGAffineTransform)ctm
{
    if ([self switchState])
        return [xfFilteredImage imageWithTransform:ctm];
    else
        return nil;
}


- (CGImageRef)currentCGImage
{
    if ([self switchState])
        return [xfFilteredImage createCGImage];
    else
        return CGImageRetain(xfImage);
}


- (CGSize)imageSize
{
    return CGSizeMake(CGImageGetWidth(xfImage), CGImageGetHeight(xfImage));
}


- (CGFloat)zoomFactor
{
	return _zoomFactor;
}


#pragma mark #### Menu Item Actions

- (IBAction)reload:(id)sender
{
	NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[[self fileURL] path] error:nil];
	NSDate* newDate = [fileAttributes valueForKey:NSFileModificationDate];
	
	//if (![newDate isEqualToDate:[self fileModificationDate]]) {
		
		[self setFileModificationDate:newDate];
		[self readFromURL:[self fileURL] ofType:[self fileType] error:nil];
		[self setupAll];
	//}
}


- (IBAction)zoomIn:(id)sender
{
	[xfZoomScrollView zoomIn];
}


- (IBAction)zoomOut:(id)sender
{
	[xfZoomScrollView zoomOut];
}

#pragma mark #### Preferences

- (IBAction)changeCleanBuffer:(id)sender
{
	cleanBuffer = [(NSButton *)sender state];
}


- (IBAction)changeAutomaticReload:(id)sender
{
	automaticReload = [(NSButton *)sender state];
}


- (IBAction)changeBackgroundColor:(id)sender
{
	[xfImageView changeBackgroundColor:[sender color]];
}


- (void)setBackgroundColor:(NSColor *)color
{
	backgroundColor = color;
}


#pragma mark #### Read/Write

- (BOOL)readFromURL:(NSURL *)absURL ofType:(NSString *)typeName error:(NSError **)outError
{	
	[xfProgressPanel makeKeyAndOrderFront:self];	
	[xfProgressIndicator setUsesThreadedAnimation:YES];
	[xfProgressIndicator startAnimation:self];
	[xfProgressStatus setStringValue:@"Prepare Loading"];
	[xfProgressStatus display];
	
    BOOL status = NO;
    
    [xfFilteredImage release];
    xfFilteredImage = nil;
	
    if (xfMetadata) CFRelease(xfMetadata);
    xfMetadata = nil;
	
    CGImageRelease(xfImage);
    xfImage = nil;
	
	cleanBuffer = [XFApp getCleanBuffer];
	
	if ([typeName rangeOfString:XFTypeNameRoot].location != NSNotFound) {
		
		NSData* xfData = [NSData dataWithContentsOfURL:absURL];
		
		NSRange startUpRange = NSMakeRange(0, MIN([xfData length], 256));
		NSData* headData = [xfData subdataWithRange:startUpRange];
		unsigned char* xfBuffer[[headData length]];
		[headData getBytes:xfBuffer];
		
		NSString* xfString = [[NSString alloc] initWithBytes:xfBuffer length:sizeof(xfBuffer) encoding:NSASCIIStringEncoding];
		NSRange headEnd = [xfString rangeOfString:separatorString];
		NSUInteger headLength = headEnd.location+headEnd.length+1;
		NSRange headRange = NSMakeRange(0, headLength);
		NSString* headString = [xfString substringWithRange:headRange];
		NSArray* headElements = [headString componentsSeparatedByCharactersInSet:[NSCharacterSet controlCharacterSet]];
		
		NSString* applicationName = [headElements objectAtIndex:0];
		NSString* fileType = [headElements objectAtIndex:1];
		NSString* imageSize = [headElements objectAtIndex:2];
		NSArray* imageSizeElements = [imageSize componentsSeparatedByString:@"x"];
		
		int imageWidth = [[imageSizeElements objectAtIndex:0] intValue];
		int imageHeight = [[imageSizeElements objectAtIndex:1] intValue];
		
		NSRange imageRange = NSMakeRange(headLength, [xfData length]-headLength);
		NSData* imageData = [xfData subdataWithRange:imageRange];
		
		if ([fileType rangeOfString:XFTypeNameXFF].location != NSNotFound) {
			
			[xfProgressStatus setStringValue:@"XFF Type Found"];
			[xfProgressStatus display];
			
			NSImage* nsImage = [[NSImage alloc] initWithData:imageData];
			
			CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)[nsImage TIFFRepresentation], NULL);
			[imageData release];
			
			if (source == nil)
				goto bail;
			
			// build options dictionary for image creation that specifies: 
			//
			// kCGImageSourceShouldCache = kCFBooleanTrue
			//      Specifies that image should be cached in a decoded form.
			//
			// kCGImageSourceShouldAllowFloat = kCFBooleanTrue
			//      Specifies that image should be returned as a floating
			//      point CGImageRef if supported by the file format.
			
			NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
									 (id)kCFBooleanTrue, (id)kCGImageSourceShouldCache,
									 (id)kCFBooleanTrue, (id)kCGImageSourceShouldAllowFloat,
									 nil];
			
			CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, (CFDictionaryRef)options);
			
			// Assign user preferred default profiles if image is not tagged with a profile
			xfImage = CGImageCreateCopyWithDefaultSpace(image);
			
			xfMetadata = (CFMutableDictionaryRef)CGImageSourceCopyPropertiesAtIndex(source, 0, (CFDictionaryRef)options);
			
			xfFilteredImage = [(XFImageFilter*)[XFImageFilter alloc] initWithImage:xfImage];
			
			CFRelease(source);
			CGImageRelease(image);
			
		} else if ([fileType rangeOfString:XFTypeNameCCI].location != NSNotFound) {
			
			[xfProgressStatus setStringValue:@"CCI Type Found"];
			[xfProgressStatus display];
			
			int channelLength = imageWidth * imageHeight;
			int channelCount = 0;
			
			unsigned char* rBuffer = (unsigned char *)malloc(channelLength);
			unsigned char* gBuffer = (unsigned char *)malloc(channelLength);
			unsigned char* bBuffer = (unsigned char *)malloc(channelLength);
			
			int i;
			if (cleanBuffer) {
				for (i=0; i<channelLength; i++) {
					rBuffer[i] = 0;
					gBuffer[i] = 0;
					bBuffer[i] = 0;
				}
			}
			
			int doubleByteNum = [imageData length] / 2;
			for (i=0; i<doubleByteNum; i++) {
				NSRange doubleByteRange = NSMakeRange(i*2, 2);
				NSData* doubleByteData = [imageData subdataWithRange:doubleByteRange];
				unsigned char* doubleByteBuffer = (unsigned char *)malloc([doubleByteData length]);
				[doubleByteData getBytes:doubleByteBuffer];
				
				Byte colorValue = (Byte)doubleByteBuffer[0];
				Byte colorLength = (Byte)doubleByteBuffer[1];
				
				int j;
				for (j=0; j<=colorLength; j++) {
					
					if (channelCount < channelLength) {
						rBuffer[channelCount] = colorValue;
					} else if (channelCount >= channelLength && channelCount < channelLength*2) {
						gBuffer[channelCount-channelLength] = colorValue;
					} else if (channelCount >= channelLength*2 && channelCount < channelLength*3) {
						bBuffer[channelCount-channelLength*2] = colorValue;
					}
					
					channelCount++;
				}
				
				free(doubleByteBuffer);
			}
			
			unsigned char* rgba = (unsigned char *)malloc(imageWidth*imageHeight*4);
			for (i=0; i<channelLength; i++) {
				rgba[i*4] = rBuffer[i];
				rgba[i*4+1] = gBuffer[i];
				rgba[i*4+2] = bBuffer[i];
				rgba[i*4+3] = 0;
			}
			
			free(rBuffer);
			free(gBuffer);
			free(bBuffer);
			
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef bitmapContext = CGBitmapContextCreate(
															   rgba,
															   imageWidth,
															   imageHeight,
															   8, // bitsPerComponent
															   4*imageWidth, // bytesPerRow
															   colorSpace,
															   kCGImageAlphaNoneSkipLast);
			
			CFRelease(colorSpace);
			
			CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
			
			free(rgba);
			
			xfImage = CGImageCreateCopyWithDefaultSpace(image);
			
			xfFilteredImage = [(XFImageFilter*)[XFImageFilter alloc] initWithImage:xfImage];
			
			CGImageRelease(image);
			
		} else if ([fileType rangeOfString:XFTypeNameMCF].location != NSNotFound) {
			
			[xfProgressStatus setStringValue:@"MCF Type Found"];
			[xfProgressStatus display];
			
			int imageSize = imageWidth * imageHeight;
			
			float columnWidth = 4.0f;
			float rowHeight = 2.0f;
			
			int xOff[8] = {0, 1, 2, 3, 0, 1, 2, 3};
			int yOff[8] = {0, 1, 0, 1, 1, 0, 1, 0};
			
			int columns = ceil(imageWidth / columnWidth);
			int rows = ceil(imageHeight / rowHeight);
			
			int gridSize = columns * rows;
			
			int rawImageWidth = columns * columnWidth;
			int rawImageHeight = rows * rowHeight;
			int rawImageSize = rawImageWidth * rawImageHeight;
			
			unsigned char* mBuffer = (unsigned char *)malloc(rawImageSize);
			unsigned char* aBuffer = (unsigned char *)malloc(rawImageSize);
			
			int i;
			if (cleanBuffer) {
				for (i=0; i<rawImageSize; i++) {
					mBuffer[i] = 0;
					aBuffer[i] = 0;
				}
			}
			
			for (i=0; i<gridSize; i++) {
				int x = fmod(i, columns) * columnWidth;
				int y = (i / columns) * rowHeight;
				
				if ([imageData length] >= i*5+5) {
					
					NSRange fiveByteRange = NSMakeRange(i*5, MIN(5, [imageData length]-i*5));
					NSData* fiveByteData = [imageData subdataWithRange:fiveByteRange];
					unsigned char* fiveByteBuffer = (unsigned char *)malloc([fiveByteData length]);
					[fiveByteData getBytes:fiveByteBuffer];
					
					int j;
					for (j=0; j<4; j++) {
						mBuffer[(x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)] = 0;
						mBuffer[(x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)] = 0;
						if (BITOP(fiveByteBuffer, j*8, &)) {
							BITOP(mBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8, |=);
							BITOP(mBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+4, |=);
						}
						if (BITOP(fiveByteBuffer, j*8+1, &)) {
							BITOP(mBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+1, |=);
							BITOP(mBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+5, |=);
						}
						if (BITOP(fiveByteBuffer, j*8+2, &)) {
							BITOP(mBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+2, |=);
							BITOP(mBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+6, |=);
						}
						if (BITOP(fiveByteBuffer, j*8+3, &)) {
							BITOP(mBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+3, |=);
							BITOP(mBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+7, |=);
						}
						if (BITOP(fiveByteBuffer, j*8+4, &)) {
							BITOP(mBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8, |=);
							BITOP(mBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+4, |=);
						}
						if (BITOP(fiveByteBuffer, j*8+5, &)) {
							BITOP(mBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+1, |=);
							BITOP(mBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+5, |=);
						}
						if (BITOP(fiveByteBuffer, j*8+6, &)) {
							BITOP(mBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+2, |=);
							BITOP(mBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+6, |=);
						}
						if (BITOP(fiveByteBuffer, j*8+7, &)) {
							BITOP(mBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+3, |=);
							BITOP(mBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+7, |=);
						}
					}
					
					for (j=0; j<4; j++) {
						aBuffer[(x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)] = 0;
						aBuffer[(x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)] = 0;
						if (BITOP(fiveByteBuffer, 32, &)) {
							BITOP(aBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8, |=);
							BITOP(aBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+4, |=);
						}
						if (BITOP(fiveByteBuffer, 33, &)) {
							BITOP(aBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+1, |=);
							BITOP(aBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+5, |=);
						}
						if (BITOP(fiveByteBuffer, 34, &)) {
							BITOP(aBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+2, |=);
							BITOP(aBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+6, |=);
						}
						if (BITOP(fiveByteBuffer, 35, &)) {
							BITOP(aBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+3, |=);
							BITOP(aBuffer, (x+xOff[j*2]+(y+yOff[j*2])*rawImageWidth)*8+7, |=);
						}
						if (BITOP(fiveByteBuffer, 36, &)) {
							BITOP(aBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8, |=);
							BITOP(aBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+4, |=);
						}
						if (BITOP(fiveByteBuffer, 37, &)) {
							BITOP(aBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+1, |=);
							BITOP(aBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+5, |=);
						}
						if (BITOP(fiveByteBuffer, 38, &)) {
							BITOP(aBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+2, |=);
							BITOP(aBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+6, |=);
						}
						if (BITOP(fiveByteBuffer, 39, &)) {
							BITOP(aBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+3, |=);
							BITOP(aBuffer, (x+xOff[j*2+1]+(y+yOff[j*2+1])*rawImageWidth)*8+7, |=);
						}
					}
					
					free(fiveByteBuffer);
				}
			}
			
			unsigned char* rgba = (unsigned char *)malloc(imageSize*4);
			int j = 0;
			for (i=0; i<rawImageSize; i++) {
				int x = fmod(i, rawImageWidth);
				int y = i / rawImageWidth;
				
				if (x<imageWidth && y<imageHeight) {					
					rgba[j*4] = mBuffer[i];
					rgba[j*4+1] = mBuffer[i];
					rgba[j*4+2] = mBuffer[i];
					rgba[j*4+3] = aBuffer[i];
					j++;
				}
			}
			
			free(mBuffer);
			free(aBuffer);
			
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef bitmapContext = CGBitmapContextCreate(
															   rgba,
															   imageWidth,
															   imageHeight,
															   8, // bitsPerComponent
															   4*imageWidth, // bytesPerRow
															   colorSpace,
															   kCGImageAlphaPremultipliedLast);
			
			CFRelease(colorSpace);
			
			CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
			
			free(rgba);
			
			xfImage = CGImageCreateCopyWithDefaultSpace(image);
			
			xfFilteredImage = [(XFImageFilter*)[XFImageFilter alloc] initWithImage:xfImage];
			
			CGImageRelease(image);
			
		} else if ([fileType rangeOfString:XFTypeName4BC].location != NSNotFound) {
			
			[xfProgressStatus setStringValue:@"4BC Type Found"];
			[xfProgressStatus display];
			
			int imageSize = imageWidth * imageHeight;
			
			float columnWidth = 4.0f;
			float rowHeight = 8.0f;
			
			int columns = ceil(imageWidth / columnWidth);
			int rows = ceil(imageHeight / rowHeight);
			
			int gridSize = columns * rows;
			
			int rawImageWidth = columns * columnWidth;
			int rawImageHeight = rows * rowHeight;
			int rawImageSize = rawImageWidth * rawImageHeight;
			
			unsigned char* rBuffer = (unsigned char *)malloc(rawImageSize);
			unsigned char* gBuffer = (unsigned char *)malloc(rawImageSize);
			unsigned char* bBuffer = (unsigned char *)malloc(rawImageSize);
			
			int i, j;
			if (cleanBuffer) {
				for (i=0; i<rawImageSize; i++) {
					rBuffer[i] = 0;
					gBuffer[i] = 0;
					bBuffer[i] = 0;
				}
			}
			
			for (i=0; i<gridSize; i++) {
				int x = fmod(i, columns) * columnWidth;
				int y = (i / columns) * rowHeight;
				
				if ([imageData length] >= i*51+17) {
				
					NSRange rSeventeenByteRange = NSMakeRange(i*51, MIN(17, [imageData length]-i*51));
					NSData* rSeventeenByteData = [imageData subdataWithRange:rSeventeenByteRange];
					unsigned char* rSeventeenByteBuffer = (unsigned char *)malloc([rSeventeenByteData length]);
					[rSeventeenByteData getBytes:rSeventeenByteBuffer];
					
					unsigned char* rHeadCurrent = (unsigned char *)malloc(1);
					rHeadCurrent[0] = rSeventeenByteBuffer[0];
					unsigned char* rHeadBuffer = (unsigned char *)malloc(2);
					
					for (j=0; j<16; j++) {
						int xOff = j / 4;
						int yOff = fmod(j, 4) * 2;
						
						rBuffer[x+xOff + (y+yOff)*rawImageWidth] = 0;
						rBuffer[x+xOff + (y+yOff+1)*rawImageWidth] = 0;
						rHeadBuffer[0] = 0;
						rHeadBuffer[1] = 0;
						
						if (BITOP(rSeventeenByteBuffer, (j+1)*8, &)) BITOP(rHeadBuffer, 0, |=);
						if (BITOP(rSeventeenByteBuffer, (j+1)*8+1, &)) BITOP(rHeadBuffer, 1, |=);
						if (BITOP(rSeventeenByteBuffer, (j+1)*8+2, &)) BITOP(rHeadBuffer, 2, |=);
						if (BITOP(rSeventeenByteBuffer, (j+1)*8+3, &)) BITOP(rHeadBuffer, 3, |=);
						if (BITOP(rSeventeenByteBuffer, (j+1)*8+4, &)) BITOP(rHeadBuffer, 8, |=);
						if (BITOP(rSeventeenByteBuffer, (j+1)*8+5, &)) BITOP(rHeadBuffer, 9, |=);
						if (BITOP(rSeventeenByteBuffer, (j+1)*8+6, &)) BITOP(rHeadBuffer, 10, |=);
						if (BITOP(rSeventeenByteBuffer, (j+1)*8+7, &)) BITOP(rHeadBuffer, 11, |=);
						
						rBuffer[x+xOff + (y+yOff)*rawImageWidth] = rHeadCurrent[0] + rHeadBuffer[0] - 7;
						rHeadCurrent[0] += rHeadBuffer[0]-7;
						rBuffer[x+xOff + (y+yOff+1)*rawImageWidth] = rHeadCurrent[0] + rHeadBuffer[1] - 7;
						rHeadCurrent[0] += rHeadBuffer[1]-7;
						
						if (fmod(j, 4) == 3) {
							rHeadCurrent[0] = rSeventeenByteBuffer[0];
						}
					}
					
					free(rSeventeenByteBuffer);
					free(rHeadCurrent);
					free(rHeadBuffer);
				}
				
				
				if ([imageData length] >= i*51+34) {
					
					NSRange gSeventeenByteRange = NSMakeRange(i*51+17, MIN(17, [imageData length]-(i*51+17)));
					NSData* gSeventeenByteData = [imageData subdataWithRange:gSeventeenByteRange];
					unsigned char* gSeventeenByteBuffer = (unsigned char *)malloc([gSeventeenByteData length]);
					[gSeventeenByteData getBytes:gSeventeenByteBuffer];
					
					unsigned char* gHeadCurrent = (unsigned char *)malloc(1);
					gHeadCurrent[0] = gSeventeenByteBuffer[0];
					unsigned char* gHeadBuffer = (unsigned char *)malloc(2);
					
					for (j=0; j<16; j++) {
						int xOff = j / 4;
						int yOff = fmod(j, 4) * 2;
						
						gBuffer[x+xOff + (y+yOff)*rawImageWidth] = 0;
						gBuffer[x+xOff + (y+yOff+1)*rawImageWidth] = 0;
						gHeadBuffer[0] = 0;
						gHeadBuffer[1] = 0;
						
						if (BITOP(gSeventeenByteBuffer, (j+1)*8, &)) BITOP(gHeadBuffer, 0, |=);
						if (BITOP(gSeventeenByteBuffer, (j+1)*8+1, &)) BITOP(gHeadBuffer, 1, |=);
						if (BITOP(gSeventeenByteBuffer, (j+1)*8+2, &)) BITOP(gHeadBuffer, 2, |=);
						if (BITOP(gSeventeenByteBuffer, (j+1)*8+3, &)) BITOP(gHeadBuffer, 3, |=);
						if (BITOP(gSeventeenByteBuffer, (j+1)*8+4, &)) BITOP(gHeadBuffer, 8, |=);
						if (BITOP(gSeventeenByteBuffer, (j+1)*8+5, &)) BITOP(gHeadBuffer, 9, |=);
						if (BITOP(gSeventeenByteBuffer, (j+1)*8+6, &)) BITOP(gHeadBuffer, 10, |=);
						if (BITOP(gSeventeenByteBuffer, (j+1)*8+7, &)) BITOP(gHeadBuffer, 11, |=);
						
						gBuffer[x+xOff + (y+yOff)*rawImageWidth] = gHeadCurrent[0] + gHeadBuffer[0] - 7;
						gHeadCurrent[0] += gHeadBuffer[0]-7;
						gBuffer[x+xOff + (y+yOff+1)*rawImageWidth] = gHeadCurrent[0] + gHeadBuffer[1] - 7;
						gHeadCurrent[0] += gHeadBuffer[1]-7;
						
						if (fmod(j, 4) == 3) {
							gHeadCurrent[0] = gSeventeenByteBuffer[0];
						}
					}
					
					free(gSeventeenByteBuffer);
					free(gHeadCurrent);
					free(gHeadBuffer);
				}				
				
				
				if ([imageData length] >= i*51+51) {
					
					NSRange bSeventeenByteRange = NSMakeRange(i*51+34, MIN(17, [imageData length]-(i*51+34)));
					NSData* bSeventeenByteData = [imageData subdataWithRange:bSeventeenByteRange];
					unsigned char* bSeventeenByteBuffer = (unsigned char *)malloc([bSeventeenByteData length]);
					[bSeventeenByteData getBytes:bSeventeenByteBuffer];
					
					unsigned char* bHeadCurrent = (unsigned char *)malloc(1);
					bHeadCurrent[0] = bSeventeenByteBuffer[0];
					unsigned char* bHeadBuffer = (unsigned char *)malloc(2);
					
					for (j=0; j<16; j++) {
						int xOff = j / 4;
						int yOff = fmod(j, 4) * 2;
						
						bBuffer[x+xOff + (y+yOff)*rawImageWidth] = 0;
						bBuffer[x+xOff + (y+yOff+1)*rawImageWidth] = 0;
						bHeadBuffer[0] = 0;
						bHeadBuffer[1] = 0;
						
						if (BITOP(bSeventeenByteBuffer, (j+1)*8, &)) BITOP(bHeadBuffer, 0, |=);
						if (BITOP(bSeventeenByteBuffer, (j+1)*8+1, &)) BITOP(bHeadBuffer, 1, |=);
						if (BITOP(bSeventeenByteBuffer, (j+1)*8+2, &)) BITOP(bHeadBuffer, 2, |=);
						if (BITOP(bSeventeenByteBuffer, (j+1)*8+3, &)) BITOP(bHeadBuffer, 3, |=);
						if (BITOP(bSeventeenByteBuffer, (j+1)*8+4, &)) BITOP(bHeadBuffer, 8, |=);
						if (BITOP(bSeventeenByteBuffer, (j+1)*8+5, &)) BITOP(bHeadBuffer, 9, |=);
						if (BITOP(bSeventeenByteBuffer, (j+1)*8+6, &)) BITOP(bHeadBuffer, 10, |=);
						if (BITOP(bSeventeenByteBuffer, (j+1)*8+7, &)) BITOP(bHeadBuffer, 11, |=);
						
						bBuffer[x+xOff + (y+yOff)*rawImageWidth] = bHeadCurrent[0] + bHeadBuffer[0] - 7;
						bHeadCurrent[0] += bHeadBuffer[0]-7;
						bBuffer[x+xOff + (y+yOff+1)*rawImageWidth] = bHeadCurrent[0] + bHeadBuffer[1] - 7;
						bHeadCurrent[0] += bHeadBuffer[1]-7;
						
						if (fmod(j, 4) == 3) {
							bHeadCurrent[0] = bSeventeenByteBuffer[0];
						}
					}
					
					free(bSeventeenByteBuffer);
					free(bHeadCurrent);
					free(bHeadBuffer);
				}				
			}
			
			unsigned char* rgba = (unsigned char *)malloc(imageSize*4);
			j = 0;
			for (i=0; i<rawImageSize; i++) {
				int x = fmod(i, rawImageWidth);
				int y = i / rawImageWidth;
				
				if (x<imageWidth && y<imageHeight) {
					rgba[j*4] = rBuffer[i];
					rgba[j*4+1] = gBuffer[i];
					rgba[j*4+2] = bBuffer[i];
					rgba[j*4+3] = 0;
					j++;
				}				
			}
			
			free(rBuffer);
			free(gBuffer);
			free(bBuffer);
			
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef bitmapContext = CGBitmapContextCreate(
															   rgba,
															   imageWidth,
															   imageHeight,
															   8, // bitsPerComponent
															   4*imageWidth, // bytesPerRow
															   colorSpace,
															   kCGImageAlphaNoneSkipLast);
			
			CFRelease(colorSpace);
			
			CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
			
			free(rgba);
			
			xfImage = CGImageCreateCopyWithDefaultSpace(image);
			
			xfFilteredImage = [(XFImageFilter*)[XFImageFilter alloc] initWithImage:xfImage];
			
			CGImageRelease(image);
			
		} else if ([fileType rangeOfString:XFTypeNameBASCII].location != NSNotFound) {
			
			[xfProgressStatus setStringValue:@"BASCII Type Found"];
			[xfProgressStatus display];
			
			int imageSize = imageWidth * imageHeight;
			
			float columnWidth = 8.0f;
			float rowHeight = 16.0f;
			
			int columns = ceil(imageWidth / columnWidth);
			int rows = ceil(imageHeight / rowHeight);
			
			int gridSize = columns * rows;
			
			int rawImageWidth = columns * columnWidth;
			int rawImageHeight = rows * rowHeight;
			int rawImageSize = rawImageWidth * rawImageHeight;
			
			unsigned char* rgbBuffer = (unsigned char *)malloc(rawImageSize);
			
			int i, j, k;
			if (cleanBuffer) {
				for (i=0; i<rawImageSize; i++) {
					rgbBuffer[i] = 0;
				}
			}
			
			for (i=0; i<gridSize; i++) {
				int x = fmod(i, columns) * columnWidth;
				int y = (i / columns) * rowHeight;
				
				if ([imageData length] >= i*rowHeight+rowHeight) {
					
					NSRange sixteenByteRange = NSMakeRange(i*rowHeight, MIN(rowHeight, [imageData length]-i*rowHeight));
					NSData* sixteenByteData = [imageData subdataWithRange:sixteenByteRange];
					unsigned char* sixteenByteBuffer = (unsigned char *)malloc([sixteenByteData length]);
					[sixteenByteData getBytes:sixteenByteBuffer];
					
					for (j=0; j<rowHeight; j++) {
						for (k=0; k<columnWidth; k++) {
							rgbBuffer[(x+k + (y+j)*rawImageWidth)] = 0;
							if (BITOP(sixteenByteBuffer, j*columnWidth+k, &)) rgbBuffer[(x+k + (y+j)*rawImageWidth)] = 255;
						}
					}
					
					free(sixteenByteBuffer);
				}
			}
			
			unsigned char* rgba = (unsigned char *)malloc(imageSize*4);
			j = 0;
			for (i=0; i<rawImageSize; i++) {
				int x = fmod(i, rawImageWidth);
				int y = i / rawImageWidth;
				
				if (x<imageWidth && y<imageHeight) {					
					rgba[j*4] = rgbBuffer[i];
					rgba[j*4+1] = rgbBuffer[i];
					rgba[j*4+2] = rgbBuffer[i];
					rgba[j*4+3] = 255;
					j++;
				}
			}
			
			free(rgbBuffer);
			
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef bitmapContext = CGBitmapContextCreate(
															   rgba,
															   imageWidth,
															   imageHeight,
															   8, // bitsPerComponent
															   4*imageWidth, // bytesPerRow
															   colorSpace,
															   kCGImageAlphaNoneSkipLast);
			
			CFRelease(colorSpace);
			
			CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
			
			free(rgba);
			
			xfImage = CGImageCreateCopyWithDefaultSpace(image);
			
			xfFilteredImage = [(XFImageFilter*)[XFImageFilter alloc] initWithImage:xfImage];
			
			CGImageRelease(image);
			
		} else if ([fileType rangeOfString:XFTypeNameBLINX].location != NSNotFound) {
			
			[xfProgressStatus setStringValue:@"BLINX Type Found"];
			[xfProgressStatus display];
			
			int imageSize = imageWidth * imageHeight;
			
			float columnWidth = 16.0f;
			float rowHeight = 8.0f;
			
			int columns = ceil(imageWidth / columnWidth);
			int rows = ceil(imageHeight / rowHeight);
			
			int gridSize = columns * rows;
			
			int rawImageWidth = columns * columnWidth;
			int rawImageHeight = rows * rowHeight;
			int rawImageSize = rawImageWidth * rawImageHeight;
			
			unsigned char* rBuffer = (unsigned char *)malloc(rawImageSize);
			unsigned char* gBuffer = (unsigned char *)malloc(rawImageSize);
			unsigned char* bBuffer = (unsigned char *)malloc(rawImageSize);
			
			int byteCount = 0;
			
			int i, j, k;
			if (cleanBuffer) {
				for (i=0; i<rawImageSize; i++) {
					rBuffer[i] = 0;
					gBuffer[i] = 0;
					bBuffer[i] = 0;
				}
			}
			
			for (i=0; i<gridSize*3; i++) {
				
				if (byteCount+4 > [imageData length]) break;
				
				NSRange fourByteRange = NSMakeRange(byteCount, 4);
				NSData* fourByteData = [imageData subdataWithRange:fourByteRange];
				
				int index;
				[fourByteData getBytes:&index length:sizeof(index)];
				index = fmod(abs(index), gridSize);
				
				int x = fmod(index, columns) * columnWidth;
				int y = (index / columns) * rowHeight;
				
				x = fmod(x, rawImageWidth);
				y = fmod(y, rawImageHeight);
				
				byteCount += 4;
				
				if (byteCount+1 > [imageData length]) break;
				
				NSRange oneByteRange = NSMakeRange(byteCount, 1);
				NSData* oneByteData = [imageData subdataWithRange:oneByteRange];
				unsigned char* oneByteBuffer = (unsigned char *)malloc(1);
				[oneByteData getBytes:oneByteBuffer];
				Byte blockLength = (Byte)oneByteBuffer[0];
				
				byteCount += 1;
				
				if (byteCount+blockLength > [imageData length]) break;
				
				NSRange blockRange = NSMakeRange(byteCount, blockLength);
				NSData* blockData = [imageData subdataWithRange:blockRange];
				unsigned char* blockBuffer = (unsigned char *)malloc([blockData length]);
				[blockData getBytes:blockBuffer];
				
				int xOff = 0;
				int yOff = 0;
				
				int xLimit = 1;
				int yLimit = 2;
				
				BOOL xUp = YES;
				
				int bid = 0;
				int jOff = 0;
				
				for (j=0; j<blockLength; j++) {
					
					int colorLength = 1;
					
					if (j+2 < blockLength) {
						if (blockBuffer[j] == blockBuffer[j+1]) {
							colorLength = blockBuffer[j+2]+1;
							j += 2;
							jOff = -2;
						}
					}
					
					for (k=0; k<colorLength; k++) {
						
						int pid = x+xOff + (y+yOff)*rawImageWidth;
						
						if (fmod(i, 3) == 0) {
							Byte rByte = (Byte)blockBuffer[j+jOff];
							rBuffer[pid] = rByte;
						} else if (fmod(i, 3) == 1) {
							Byte gByte = (Byte)blockBuffer[j+jOff];
							gBuffer[pid] = gByte;
						} else if (fmod(i, 3) == 2) {
							Byte bByte = (Byte)blockBuffer[j+jOff];
							bBuffer[pid] = bByte;
						}
						
						if (bid==35 || bid==51 || bid==67 || bid==83 || bid==99 || bid==112 || bid==121 || bid==126) {
							yOff++;
						}
						
						if (bid==106 || bid==117 || bid==124) {
							xOff++;
						}
						
						if (xUp) {
							xOff++;
							yOff--;
						} else {
							xOff--;
							yOff++;
						}
						
						if (xOff == xLimit) {
							xUp = NO;
							xLimit += 2;
							xLimit = MIN(columnWidth-1, xLimit);
						}
						
						if (yOff == yLimit) {
							xUp = YES;
							yLimit += 2;
							yLimit = MIN(rowHeight-1, yLimit);
						}
						
						xOff = MIN(columnWidth-1, MAX(0, xOff));
						yOff = MIN(rowHeight-1, MAX(0, yOff));
						
						bid++;
					}
					
					jOff = 0;
				}
								
				byteCount += blockLength;
				
				free(oneByteBuffer);
				free(blockBuffer);
			}
			
			unsigned char* rgba = (unsigned char *)malloc(imageSize*4);
			j = 0;
			for (i=0; i<rawImageSize; i++) {
				int x = fmod(i, rawImageWidth);
				int y = i / rawImageWidth;
				
				if (x<imageWidth && y<imageHeight) {					
					rgba[j*4] = rBuffer[i];
					rgba[j*4+1] = gBuffer[i];
					rgba[j*4+2] = bBuffer[i];
					rgba[j*4+3] = 0;
					j++;
				}
			}
			
			free(rBuffer);
			free(gBuffer);
			free(bBuffer);
			
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef bitmapContext = CGBitmapContextCreate(
															   rgba,
															   imageWidth,
															   imageHeight,
															   8, // bitsPerComponent
															   4*imageWidth, // bytesPerRow
															   colorSpace,
															   kCGImageAlphaNoneSkipLast);
			
			CFRelease(colorSpace);
			
			CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
			
			free(rgba);
			
			xfImage = CGImageCreateCopyWithDefaultSpace(image);
			
			xfFilteredImage = [(XFImageFilter*)[XFImageFilter alloc] initWithImage:xfImage];
			
			CGImageRelease(image);
			
		} else if ([fileType rangeOfString:XFTypeNameUSPEC].location != NSNotFound) {
			
			[xfProgressStatus setStringValue:@"USPEC Type Found"];
			[xfProgressStatus display];
			
			int imageSize = imageWidth * imageHeight;
			int dataSize = [imageData length] / 4;
			int colorStep = (255 + 255*256 + 255*256*256) / dataSize;
			
			unsigned char* rBuffer = (unsigned char *)malloc(imageSize);
			unsigned char* gBuffer = (unsigned char *)malloc(imageSize);
			unsigned char* bBuffer = (unsigned char *)malloc(imageSize);
			
			int i;
			if (cleanBuffer) {
				for (i=0; i<imageSize; i++) {
					rBuffer[i] = 0;
					gBuffer[i] = 0;
					bBuffer[i] = 0;
				}
			}
			
			for (i=0; i<dataSize; i++) {
				
				NSRange fourByteRange = NSMakeRange(i*4, 4);
				NSData* fourByteData = [imageData subdataWithRange:fourByteRange];
				
				int index;
				[fourByteData getBytes:&index length:sizeof(index)];
				index = fmod(abs(index), imageSize);
				
				int colorIndex = colorStep * i;
				
				int bRest = fmod(colorIndex, 256.0f*256.0f);
				int rRest = fmod(bRest, 256.0f);
				
				
				rBuffer[index] = (unsigned char)(rRest);
				gBuffer[index] = (unsigned char)(bRest/256.0f);
				bBuffer[index] = (unsigned char)(colorIndex/(256.0f*256.0f));
			}
			
			unsigned char* rgba = (unsigned char *)malloc(imageSize*4);
			for (i=0; i<imageSize; i++) {
				rgba[4*i] = rBuffer[i];
				rgba[4*i+1] = gBuffer[i];
				rgba[4*i+2] = bBuffer[i];
				rgba[4*i+3] = 0;
			}
			
			free(rBuffer);
			free(gBuffer);
			free(bBuffer);
			
			CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
			CGContextRef bitmapContext = CGBitmapContextCreate(
															   rgba,
															   imageWidth,
															   imageHeight,
															   8, // bitsPerComponent
															   4*imageWidth, // bytesPerRow
															   colorSpace,
															   kCGImageAlphaNoneSkipLast);
			
			CFRelease(colorSpace);
			
			CGImageRef image = CGBitmapContextCreateImage(bitmapContext);
			
			free(rgba);
			
			xfImage = CGImageCreateCopyWithDefaultSpace(image);
			
			xfFilteredImage = [(XFImageFilter*)[XFImageFilter alloc] initWithImage:xfImage];
			
			CGImageRelease(image);
		}
		
		[xfString dealloc];
		
	} else {
		
		[xfProgressStatus setStringValue:@"Loading..."];
		[xfProgressStatus display];
		
		CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)absURL, NULL);
		
		if (source == nil)
			goto bail;
		
		// build options dictionary for image creation that specifies: 
		//
		// kCGImageSourceShouldCache = kCFBooleanTrue
		//      Specifies that image should be cached in a decoded form.
		//
		// kCGImageSourceShouldAllowFloat = kCFBooleanTrue
		//      Specifies that image should be returned as a floating
		//      point CGImageRef if supported by the file format.
		
		NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
								 (id)kCFBooleanTrue, (id)kCGImageSourceShouldCache,
								 (id)kCFBooleanTrue, (id)kCGImageSourceShouldAllowFloat,
								 nil];
		
		CGImageRef image = CGImageSourceCreateImageAtIndex(source, 0, (CFDictionaryRef)options);
		
		// Assign user preferred default profiles if image is not tagged with a profile
		xfImage = CGImageCreateCopyWithDefaultSpace(image);
		
		xfMetadata = (CFMutableDictionaryRef)CGImageSourceCopyPropertiesAtIndex(source, 0, (CFDictionaryRef)options);
		
		xfFilteredImage = [(XFImageFilter*)[XFImageFilter alloc] initWithImage:xfImage];
		
		CFRelease(source);
		CGImageRelease(image);
	}
	
	if (xfImage != nil)
		status = YES;
	
bail:
	
    if (status==NO && outError)
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadCorruptFileError userInfo:nil];
    
	[xfProgressIndicator stopAnimation:self];
	[xfProgressPanel orderOut:self];
	
    return status;
}


#pragma mark -


/* 
 These methods NSDocument allow this document to present custom interface
 when saving.  The interface have a custom format popup, quality slider,
 and compression type popup.
 */

- (NSMutableDictionary *)saveMetaAndOpts
{
    if (xfSaveMetaAndOpts == nil)
    {
        if (xfMetadata)
            xfSaveMetaAndOpts = CFDictionaryCreateMutableCopy(nil, 0, xfMetadata);
        else
            xfSaveMetaAndOpts = CFDictionaryCreateMutable(nil, 0,
														 &kCFTypeDictionaryKeyCallBacks,  &kCFTypeDictionaryValueCallBacks);
		
        // save a dictionary of the image properties
        CFDictionaryRef tiffProfs = CFDictionaryGetValue(xfSaveMetaAndOpts, kCGImagePropertyTIFFDictionary);
		CFShow(tiffProfs);
        CFMutableDictionaryRef tiffProfsMut;
        if (tiffProfs)
            tiffProfsMut = CFDictionaryCreateMutableCopy(nil, 0, tiffProfs);
        else
            tiffProfsMut = CFDictionaryCreateMutable(nil, 0,
													 &kCFTypeDictionaryKeyCallBacks,  &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(xfSaveMetaAndOpts, kCGImagePropertyTIFFDictionary, tiffProfsMut);
        CFRelease(tiffProfsMut);
        
        CFDictionarySetValue(xfSaveMetaAndOpts, kCGImageDestinationLossyCompressionQuality, 
							 [NSNumber numberWithFloat:0.85]);
    }
    return (NSMutableDictionary *)xfSaveMetaAndOpts;
}


- (NSArray *)saveTypes
{
    NSArray* wt = [XFImageDocument writableTypes];
    NSMutableArray* wtl = [NSMutableArray arrayWithCapacity:0];
    NSEnumerator* enumerator = [wt objectEnumerator];
    NSString* type;
    while ((type = [enumerator nextObject]))
    {
		if ([type rangeOfString:XFTypeNameRoot].location != NSNotFound) {
			[wtl addObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:
			  type, @"uti", XFIOLocalizedString(type), @"localized", nil]];
		} else {
			[wtl addObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:
			  type, @"uti", ImageIOLocalizedString(type), @"localized", nil]];
		}        
    }
	return wtl;
}


- (NSString *)saveType
{
    if (xfSaveUTI==nil)
    {
        if ([[XFImageDocument writableTypes] containsObject:[self fileType]])
            xfSaveUTI = [[self fileType] retain];
        else
            xfSaveUTI = @"public.tiff";
    }
    return xfSaveUTI;
}


- (void)setSaveType:(NSString *)uti
{
    [self willChangeValueForKey:@"saveTab"];
    [xfSaveUTI release];
    xfSaveUTI = [uti retain];
    [self didChangeValueForKey:@"saveTab"];
    
    // get the file extension so we can control file types shown
    CFDictionaryRef utiDecl = UTTypeCopyDeclaration((CFStringRef)xfSaveUTI);
    CFDictionaryRef utiSpec = CFDictionaryGetValue(utiDecl, kUTTypeTagSpecificationKey);
    CFTypeRef ext = CFDictionaryGetValue(utiSpec, kUTTagClassFilenameExtension);
	
    NSSavePanel* savePanel = (NSSavePanel *)[xfSavePanelView window];
    if (CFGetTypeID(ext) == CFStringGetTypeID())
        [savePanel setRequiredFileType:(NSString *)ext];
    else
        [savePanel setAllowedFileTypes:(NSArray *)ext];
	
    CFRelease(utiDecl);
}


// Binding method for save panel's tabless tab view.
// This tabless tabview (below file type popup) contains 
// panes with apporpiate UI for various file format. 
// In this simple implementaion:
//  pane index 2 contains the compression type popup for TIFF,
//  pane index 1 contains the quality slider for JPG and JP2,
//  pane index 0 is empty for all other formats.
//
- (int)saveTab
{
    // return the appropriate tab view index based on chosen format
    if ([xfSaveUTI isEqual:@"public.tiff"])
        return 2;
    else if ([xfSaveUTI isEqual:@"public.jpeg"] || [xfSaveUTI isEqual:@"public.jpeg-2000"] || [xfSaveUTI isEqual:XFTypeNameCCI] || [xfSaveUTI isEqual:XFTypeNameBLINX])
        return 1;
    else
        return 0;
}


// Binding methods for save panel's image quality slider.
// The slider's value is bound to the kCGImageDestinationLossyCompressionQuality
// value of the metadata/options dictionary to use when saving.
//
// We set the kCGImageDestinationLossyCompressionQuality option to specify
// the compression quality to use when writing to a jpeg or jp2 image
// desination. 0.0=maximum compression, 1.0=lossless compression
//
- (NSNumber *)saveQuality
{
    return [[self saveMetaAndOpts] objectForKey:(id)kCGImageDestinationLossyCompressionQuality];
}


- (void)setSaveQuality:(NSNumber *)q
{
    [[self saveMetaAndOpts] setObject:q forKey:(id)kCGImageDestinationLossyCompressionQuality];
}


// Binding methods for save panel's image compression popup.
// The popup's tag value is bound to the kCGImagePropertyTIFFCompression
// value of the kCGImagePropertyTIFFDictionary of the 
// metadata/options dictionary to use when saving.
//
// We set kCGImagePropertyTIFFDictionary > kCGImagePropertyTIFFCompression
// to specify the compression type to use when writing to a tiff image 
// destination. 1=no compression, 5=LZW,  32773=PackBits.
//
// Note: values for the compression options as just described (5=LZW, and so on)
//       are not currently defined in the Quartz (Core Graphics) interfaces, but 
//       these are the same as those defined in the Cocoa interfaces for 
//       _NSTIFFCompression as shown here (taken from NSBitmapImageRep.h):
//
// typedef enum _NSTIFFCompression {
//     NSTIFFCompressionNone		= 1,
//     NSTIFFCompressionCCITTFAX3	= 3,		/* 1 bps only */
//     NSTIFFCompressionCCITTFAX4	= 4,		/* 1 bps only */
//     NSTIFFCompressionLZW         = 5,
//     NSTIFFCompressionJPEG		= 6,		/* No longer supported for input or output */
//     NSTIFFCompressionNEXT		= 32766,	/* Input only */
//     NSTIFFCompressionPackBits	= 32773,
//     NSTIFFCompressionOldJPEG		= 32865		/* No longer supported for input or output */
// } NSTIFFCompression;
//


- (int)saveCompression
{
    NSNumber* val = [[[self saveMetaAndOpts] objectForKey:(id)kCGImagePropertyTIFFDictionary]
					 objectForKey:(id)kCGImagePropertyTIFFCompression];
    int comp = [val intValue];
    return (comp==1 || comp==5 || comp==32773) ? comp : 1;
}


- (void)setSaveCompression:(int)c
{
    [[[self saveMetaAndOpts] objectForKey:(id)kCGImagePropertyTIFFDictionary]
	 setObject:[NSNumber numberWithInt:c]
	 forKey:(id)kCGImagePropertyTIFFCompression];
}


- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    [savePanel setAccessoryView: xfSavePanelView];
	
    [self setSaveType:[self saveType]];
    
    return YES;
}


- (NSString *)fileTypeFromLastRunSavePanel
{
    return xfSaveUTI;
}

#pragma mark -


// reload the image and update the user interface after writing the file.
//
- (BOOL)saveToURL:(NSURL *)absURL ofType:(NSString *)type forSaveOperation:(NSSaveOperationType)saveOp error:(NSError **)outError
{
	
	[xfProgressPanel makeKeyAndOrderFront:self];	
	[xfProgressIndicator setUsesThreadedAnimation:YES];
	[xfProgressIndicator startAnimation:self];
	[xfProgressStatus setStringValue:@"Prepare Saving"];
	[xfProgressStatus display];
	
    BOOL status = [super saveToURL:absURL ofType:type forSaveOperation:saveOp error:outError];
	
    if (status == YES && (saveOp == NSSaveOperation || saveOp == NSSaveAsOperation))
    {
        NSURL* url = [self fileURL];
		
        // reload the image (this could fail)
        status = [self readFromURL:url ofType:type error:outError];
		
        // re-initialize the UI
        [self setupAll];
    }
	
    return status;
}
 

// This actually writes the file using CGImageDesination API
//
- (BOOL)writeToURL:(NSURL *)absURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOp originalContentsURL:(NSURL *)absOrigURL error:(NSError **)outError
{	
    BOOL status = NO;
	
	if ([typeName rangeOfString:XFTypeNameRoot].location != NSNotFound) {
		
		NSMutableData* data = [NSMutableData dataWithCapacity:0];
		
		NSData* head;
		const char* utfAppString = [XFAppString UTF8String];
		
		head = [NSData dataWithBytes:utfAppString length:strlen(utfAppString)+1];
		
		NSData* type;
		const char *utfTypeString = [typeName UTF8String];
		
		type = [NSData dataWithBytes:utfTypeString length:strlen(utfTypeString)+1];
		
		//ADD XF DATA
		NSData* imgBytes;
		if ([typeName rangeOfString:XFTypeNameXFF].location != NSNotFound) {
			[xfProgressStatus setStringValue:@"Decode XFF"];
			[xfProgressStatus display];
			imgBytes = [xfImageView dataInXFF];
		} else if ([typeName rangeOfString:XFTypeNameCCI].location != NSNotFound) {
			[xfProgressStatus setStringValue:@"Decode CCI"];
			[xfProgressStatus display];
			imgBytes = [xfImageView dataInCCI];
		} else if ([typeName rangeOfString:XFTypeNameMCF].location != NSNotFound) {
			[xfProgressStatus setStringValue:@"Decode MCF"];
			[xfProgressStatus display];
			imgBytes = [xfImageView dataInMCF];
		} else if ([typeName rangeOfString:XFTypeName4BC].location != NSNotFound) {
			[xfProgressStatus setStringValue:@"Decode 4BC"];
			[xfProgressStatus display];
			imgBytes = [xfImageView dataIn4BC];
		} else if ([typeName rangeOfString:XFTypeNameBASCII].location != NSNotFound) {
			[xfProgressStatus setStringValue:@"Decode BASCII"];
			[xfProgressStatus display];
			imgBytes = [xfImageView dataInBASCII];
		} else if ([typeName rangeOfString:XFTypeNameBLINX].location != NSNotFound) {
			[xfProgressStatus setStringValue:@"Decode BLINX"];
			[xfProgressStatus display];
			imgBytes = [xfImageView dataInBLINX];
		} else if ([typeName rangeOfString:XFTypeNameUSPEC].location != NSNotFound) {
			[xfProgressStatus setStringValue:@"Decode USPEC"];
			[xfProgressStatus display];
			imgBytes = [xfImageView dataInUSPEC];
		}
		
		[data appendData:head];
		[data appendData:type];
		[data appendData:imgBytes];
		
		[xfProgressStatus setStringValue:@"Write to Disk"];
		[xfProgressStatus display];
		status = [data writeToURL:absURL atomically:YES];
		
	} else {
		
		CGImageRef image = [self currentCGImage];
		if (image == nil)
			goto bail;
		
		CGImageDestinationRef dest = CGImageDestinationCreateWithURL((CFURLRef)absURL, (CFStringRef)typeName, 1, nil);
		if (dest == nil)
			goto bail;
		
		[xfProgressStatus setStringValue:@"Write to Disk"];
		[xfProgressStatus display];
		CGImageDestinationAddImage(dest, image, (CFDictionaryRef)[self saveMetaAndOpts]);
		
		status = CGImageDestinationFinalize(dest);
		
		CGImageRelease(image);
	}

bail:	
	
    if (status == NO && outError)
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
    
	[xfProgressIndicator stopAnimation:self];
	[xfProgressPanel orderOut:self];
	
    return status;
}


#pragma mark #### Notifications

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[xfImageView changeBackgroundColor:[XFApp getBackgroundColor]];
	automaticReload = [XFApp getAutomaticReload];
	cleanBuffer = [XFApp getCleanBuffer];
	
	if (automaticReload) {
		NSDictionary* fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[[self fileURL] path] error:nil];
		NSDate* newDate = [fileAttributes valueForKey:NSFileModificationDate];
		
		if (![newDate isEqualToDate:[self fileModificationDate]]) {
			
			[self setFileModificationDate:newDate];
			[self readFromURL:[self fileURL] ofType:[self fileType] error:nil];
			[self setupAll];
		}
	}
	
	NSWindow* window = [self windowForSheet];
	[window makeKeyAndOrderFront:nil];
}


- (void)windowDidResignKey:(NSNotification *)notification
{
}


#pragma mark -


- (void)setPrintInfo:(NSPrintInfo *)info
{
    if (xfPrintInfo == info)
        return;
    
    [xfPrintInfo autorelease];
    xfPrintInfo = [info copyWithZone:[self zone]];
}


- (NSPrintInfo *)printInfo
{
    if (xfPrintInfo == nil)
        [self setPrintInfo: [NSPrintInfo sharedPrintInfo]];
    
    return xfPrintInfo;
}


- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error: (NSError **)outError
{
    NSPrintInfo* printInfo = [self printInfo];
	
    NSSize paperSize = [printInfo paperSize];
    NSRect printableRect = [printInfo imageablePageBounds];
	
    // calculate page margins
    float marginL = printableRect.origin.x;
    float marginR = paperSize.width - (printableRect.origin.x + printableRect.size.width);
    float marginB = printableRect.origin.y;
    float marginT = paperSize.height - (printableRect.origin.y + printableRect.size.height);
	
    // Make sure margins are symetric and positive
    float marginLR = MAX(0,MAX(marginL,marginR));
    float marginTB = MAX(0,MAX(marginT,marginB));
    
    // Tell printInfo what the nice new margins are
    [printInfo setLeftMargin:   marginLR];
    [printInfo setRightMargin:  marginLR];
    [printInfo setTopMargin:    marginTB];
    [printInfo setBottomMargin: marginTB];
	
    NSRect printViewFrame = {};
    printViewFrame.size.width = paperSize.width - marginLR*2;
    printViewFrame.size.height = paperSize.height - marginTB*2;
	
    XFPrintView* printView = [[XFPrintView alloc] initWithFrame:printViewFrame document:self];
	
    NSPrintOperation* printOp = [NSPrintOperation printOperationWithView:printView printInfo:printInfo];
	
    if (outError) // Clear error.
        *outError = NULL;
	
    [printView release];
	
    return printOp;
}

@end
