//
//  XFImageView.m
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import "XFImageView.h"
#import "XFImageDocument.h"

#import <Quartz/Quartz.h>


#define BITOP(a,b,op) \
((a)[(size_t)(b)/(8*sizeof *(a))] op (size_t)1<<((size_t)(b)%(8*sizeof *(a))))

// BITOP(array, 40, |=); /* sets bit 40 */
// BITOP(array, 41, ^=); /* toggles bit 41 */
// if (BITOP(array, 42, &)) return 0; /* tests bit 42 */
// BITOP(array, 43, &=~); /* clears bit 43 */


static NSString* separatorString = @">data>";

static unsigned char bAscii0[16] = {0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0};
static unsigned char bAscii1[16] = {0x88, 0x88, 0x22, 0x22, 0x88, 0x88, 0x22, 0x22, 0x88, 0x88, 0x22, 0x22, 0x88, 0x88, 0x22, 0x22};
static unsigned char bAscii2[16] = {0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55, 0xAA, 0xAA, 0x55, 0x55};
static unsigned char bAscii3[16] = {0xEE, 0xEE, 0xBB, 0xBB, 0xEE, 0xEE, 0xBB, 0xBB, 0xEE, 0xEE, 0xBB, 0xBB, 0xEE, 0xEE, 0xBB, 0xBB};
static unsigned char bAscii4[16] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};


@implementation XFImageView

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}


- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [[NSNotificationCenter defaultCenter]
		 addObserver:self selector:@selector(newScreenProfile:)
		 name:NSWindowDidChangeScreenProfileNotification object:nil];
    }
    return self;
}


#pragma mark -

- (CMDisplayIDType)displayID
{
    return (CMDisplayIDType)[[[[[self window] screen] deviceDescription] objectForKey:@"NSScreenNumber"] longValue];
}


- (BOOL)isFlipped
{
    return YES;	
}


- (BOOL)isOpaque
{
    return YES;
}


#pragma mark -

- (void)changeBackgroundColor:(NSColor *)color
{
	backgroundColor = color;
	[self setNeedsDisplay:YES];
}


- (void)drawImage
{
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    if (context==nil)
        return;
	
    CGImageRef image = [xfImageDoc currentCGImage];
    if (image==nil)
        return;
	
    NSRect viewBounds = [self bounds];
    CGRect imageRect = {{0,0}, [xfImageDoc imageSize]};
	
    CGAffineTransform ctm = [xfImageDoc imageTransform];
	
    CGSize ctmdSize = CGRectApplyAffineTransform(imageRect, ctm).size;	
    ctm.tx += viewBounds.origin.x + (viewBounds.size.width - ctmdSize.width)/2;
    ctm.ty += viewBounds.origin.y + (viewBounds.size.height - ctmdSize.height)/2;
	
    CGContextConcatCTM(context, ctm);
    
    //CGInterpolationQuality q = [self inLiveResize] ? NSImageInterpolationNone : NSImageInterpolationHigh;
	CGInterpolationQuality q = NSImageInterpolationNone;
    CGContextSetInterpolationQuality(context, q);
    
    // now draw using updated transform
    CGContextDrawImage(context, imageRect, image);
	
    CGImageRelease(image);
}


- (void)drawCIImage
{
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    if (context==nil)
        return;
	
    CIImage* image = [xfImageDoc currentCIImageWithTransform:[xfImageDoc imageTransform]];
    if (image==nil)
        return;
	
    NSRect viewBounds = [self bounds];
    CGRect sRect = [image extent];
    CGRect dRect = sRect;
    dRect.origin.x = viewBounds.origin.x + (viewBounds.size.width - sRect.size.width)/2;
    dRect.origin.y = viewBounds.origin.y + (viewBounds.size.height - sRect.size.height)/2;
	
    CIContext* ciContext = [CIContext contextWithCGContext:context options:nil];
    [ciContext drawImage:image inRect:dRect fromRect:sRect];
}


- (void)drawRect:(NSRect)rect
{
	NSSize imageSize = NSSizeFromCGSize([xfImageDoc imageSize]);
	NSRect viewBounds = [xfImageDoc visibleRect];
	NSRect imageBounds = NSMakeRect(0, 0, MAX(imageSize.width, viewBounds.size.width), MAX(imageSize.height, viewBounds.size.height));
	[self setFrame:imageBounds];
    
	[backgroundColor set];
    [NSBezierPath fillRect:[self bounds]];
	
    if ([xfImageDoc switchState])
        [self drawCIImage];
    else
        [self drawImage];
}


- (void)viewDidEndLiveResize
{
    if ([xfImageDoc switchState]==NO)
        [self setNeedsDisplay:YES];
}


- (void)newScreenProfile:(NSNotification*)n
{
}


#pragma mark #### GET DATA

- (NSData *)dataInXFF
{	
    CGImageRef cgImage = [xfImageDoc currentCGImage];
    if (cgImage==nil)
        return nil;
	
	NSMutableData* xffData = [NSMutableData dataWithCapacity:0];
	
	NSRect bounds = NSMakeRect(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
	NSImage* image = [[NSImage alloc] initWithSize:bounds.size];
	
	[image lockFocus];
	
	CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect*)&bounds, cgImage);
    
	[image unlockFocus];
	
	NSData* data = [image TIFFRepresentation];
	[image release];
	
	
	//PROPERTIES
	NSString* sizeString = [NSString stringWithFormat:@"%dx%d", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
	const char* utfSizeString = [sizeString UTF8String];
	
	NSData* size = [NSData dataWithBytes:utfSizeString length:strlen(utfSizeString)+1];
	
	//SEPARATOR
	const char* utfSeparatorString = [separatorString UTF8String];
	
	NSData* separator = [NSData dataWithBytes:utfSeparatorString length:strlen(utfSeparatorString)+1];
	
	[xffData appendData:size];
	[xffData appendData:separator];
	[xffData appendData:data];
	
	CGImageRelease(cgImage);
	
	return xffData;
}


- (NSData *)dataInCCI
{
	CGImageRef cgImage = [xfImageDoc currentCGImage];
    if (cgImage==nil)
        return nil;
	
	NSMutableData* cciData = [NSMutableData dataWithCapacity:0];
	
	NSRect bounds = NSMakeRect(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
	NSImage* image = [[NSImage alloc] initWithSize:bounds.size];
	
	[image lockFocus];
	
	CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect*)&bounds, cgImage);
    
	[image unlockFocus];
	
	NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	[image release];
	
	NSMutableData* rData = [NSMutableData dataWithCapacity:0];
	NSMutableData* gData = [NSMutableData dataWithCapacity:0];
	NSMutableData* bData = [NSMutableData dataWithCapacity:0];
	
	NSColor* color = [bitmap colorAtX:0 y:0];
	CGFloat rFloat = lround(255.0f * [color redComponent]);
	CGFloat gFloat = lround(255.0f * [color greenComponent]);
	CGFloat bFloat = lround(255.0f * [color blueComponent]);
	
	Byte rByteBuffer = (Byte)rFloat;
	Byte rByteCount = 0;
	Byte gByteBuffer = (Byte)gFloat;
	Byte gByteCount = 0;
	Byte bByteBuffer = (Byte)bFloat;
	Byte bByteCount = 0;
	
	float quality = [[xfImageDoc saveQuality] floatValue];
	int qualityOffset = lround((1.0f-quality)*10);
	
	int numPixels = CGImageGetWidth(cgImage) * CGImageGetHeight(cgImage);
	int i;
	for (i=1; i<numPixels; i++) {
		int x = fmod(i, CGImageGetWidth(cgImage));
		int y = i / CGImageGetWidth(cgImage);
		
		NSColor* color = [bitmap colorAtX:x y:y];
		
		CGFloat rFloat = lround(255.0f * [color redComponent]);
		Byte rByte = (Byte)rFloat;
		
		if (rByte < rByteBuffer-qualityOffset || rByte > rByteBuffer+qualityOffset || rByteCount >= 255) {
			
			unsigned char* rValueChar = (unsigned char *)&rByteBuffer;
			unsigned char* rCountChar = (unsigned char *)&rByteCount;
			[rData appendBytes:rValueChar length:sizeof(unsigned char)];
			[rData appendBytes:rCountChar length:sizeof(unsigned char)];

			rByteBuffer = rByte;
			rByteCount = 0;
		}
		else {
			rByteCount++;
		}

		
		CGFloat gFloat = lround(255.0f * [color greenComponent]);
		Byte gByte = (Byte)gFloat;
		
		if (gByte < gByteBuffer-qualityOffset || gByte > gByteBuffer+qualityOffset || gByteCount >= 255) {
			unsigned char* gValueChar = (unsigned char *)&gByteBuffer;
			unsigned char* gCountChar = (unsigned char *)&gByteCount;
			[gData appendBytes:gValueChar length:sizeof(unsigned char)];
			[gData appendBytes:gCountChar length:sizeof(unsigned char)];
			
			gByteBuffer = gByte;
			gByteCount = 0;
		}
		else {
			gByteCount++;
		}
		
		
		CGFloat bFloat = lround(255.0f * [color blueComponent]);
		Byte bByte = (Byte)bFloat;
		
		if (bByte < bByteBuffer-qualityOffset || bByte > bByteBuffer+qualityOffset || bByteCount >= 255) {
			unsigned char* bValueChar = (unsigned char *)&bByteBuffer;
			unsigned char* bCountChar = (unsigned char *)&bByteCount;
			[bData appendBytes:bValueChar length:sizeof(unsigned char)];
			[bData appendBytes:bCountChar length:sizeof(unsigned char)];
			
			bByteBuffer = bByte;
			bByteCount = 0;
		}
		else {
			bByteCount++;
		}
	}
	
	unsigned char* rValueChar = (unsigned char *)&rByteBuffer;
	unsigned char* rCountChar = (unsigned char *)&rByteCount;
	[rData appendBytes:rValueChar length:sizeof(unsigned char)];
	[rData appendBytes:rCountChar length:sizeof(unsigned char)];
	
	unsigned char* gValueChar = (unsigned char *)&gByteBuffer;
	unsigned char* gCountChar = (unsigned char *)&gByteCount;
	[gData appendBytes:gValueChar length:sizeof(unsigned char)];
	[gData appendBytes:gCountChar length:sizeof(unsigned char)];
	
	unsigned char* bValueChar = (unsigned char *)&bByteBuffer;
	unsigned char* bCountChar = (unsigned char *)&bByteCount;
	[bData appendBytes:bValueChar length:sizeof(unsigned char)];
	[bData appendBytes:bCountChar length:sizeof(unsigned char)];
	
	
	//PROPERTIES
	NSString* sizeString = [NSString stringWithFormat:@"%dx%d", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
	const char* utfSizeString = [sizeString UTF8String];
	
	NSData* size = [NSData dataWithBytes:utfSizeString length:strlen(utfSizeString)+1];
	
	//SEPARATOR
	const char* utfSeparatorString = [separatorString UTF8String];
	
	NSData* separator = [NSData dataWithBytes:utfSeparatorString length:strlen(utfSeparatorString)+1];
	
	[cciData appendData:size];
	[cciData appendData:separator];
	[cciData appendData:rData];
	[cciData appendData:gData];
	[cciData appendData:bData];
	
	CGImageRelease(cgImage);
	
	return cciData;
}


- (NSData *)dataInMCF
{
	CGImageRef cgImage = [xfImageDoc currentCGImage];
    if (cgImage==nil)
        return nil;
	
	NSMutableData* mcfData = [NSMutableData dataWithCapacity:0];
	
	NSRect bounds = NSMakeRect(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
	NSImage* image = [[NSImage alloc] initWithSize:bounds.size];
	
	[image lockFocus];
	
	CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect*)&bounds, cgImage);
    
	[image unlockFocus];
	
	NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	[image release];
	
	NSMutableData* mData = [NSMutableData dataWithCapacity:0];
	
	float columnWidth = 4.0f;
	float rowHeight = 2.0f;
	
	int xOff[8] = {0, 1, 2, 3, 0, 1, 2, 3};
	int yOff[8] = {0, 1, 0, 1, 1, 0, 1, 0};
	
	int columns = ceil(CGImageGetWidth(cgImage) / columnWidth);
	int rows = ceil(CGImageGetHeight(cgImage) / rowHeight);
	
	int gridSize = columns * rows;
	
	int i;
	for (i=0; i<gridSize; i++) {
		int x = fmod(i, columns) * columnWidth;
		int y = (i / columns) * rowHeight;
		
		CGFloat alpha0527 = 0.0f;
		CGFloat alpha4163 = 0.0f;
		
		int j;
		for (j=0; j<8; j+=2) {
			
			//PIXEL0
			NSColor* color0 = [bitmap colorAtX:x+xOff[j] y:y+yOff[j]];
			
			CGFloat pixel0Float = lround(15.0f * ([color0 redComponent] + [color0 greenComponent] + [color0 blueComponent]) / 3.0f);
			Byte pixel0Byte = (Byte)pixel0Float;
			unsigned char* pixel0Char = (unsigned char *)&pixel0Byte;
			
			//PIXEL1
			NSColor* color1 = [bitmap colorAtX:x+xOff[j+1] y:y+yOff[j+1]];
			
			CGFloat pixel1Float = lround(15.0f * ([color1 redComponent] + [color1 greenComponent] + [color1 blueComponent]) / 3.0f);
			Byte pixel1Byte = (Byte)pixel1Float;
			unsigned char* pixel1Char = (unsigned char *)&pixel1Byte;
			
			//PIXEL MIX
			Byte defaultPixelByte = 0;
			unsigned char* pixelChar = (unsigned char *)&defaultPixelByte;
			
			int k;
			for (k=0; k<8; k++) {
				if (k<4) {
					if (BITOP(pixel0Char, k, &)) BITOP(pixelChar, k, |=);
				} else {
					if (BITOP(pixel1Char, k-4, &)) BITOP(pixelChar, k, |=);
				}
			}
			
			[mData appendBytes:pixelChar length:sizeof(unsigned char)];			
			
			//ALPHA
			if (j<4) {
				alpha0527 += lround(15 * [color0 alphaComponent]);
				alpha0527 += lround(15 * [color1 alphaComponent]);
			} else {
				alpha4163 += lround(15 * [color0 alphaComponent]);
				alpha4163 += lround(15 * [color1 alphaComponent]);
			}			
		}
		
		Byte alpha0527Byte = (Byte)(alpha0527*0.25f);
		unsigned char* alpha0527Char = (unsigned char *)&alpha0527Byte;
		
		Byte alpha4163Byte = (Byte)(alpha4163*0.25f);
		unsigned char* alpha4163Char = (unsigned char *)&alpha4163Byte;
		
		Byte defaultAlphaByte = 0;
		unsigned char* alphaChar = (unsigned char *)&defaultAlphaByte;
		
		for (j=0; j<8; j++) {
			if (j<4) {
				if (BITOP(alpha0527Char, j, &)) BITOP(alphaChar, j, |=);
			} else {
				if (BITOP(alpha4163Char, j-4, &)) BITOP(alphaChar, j, |=);
			}
		}
		
		[mData appendBytes:alphaChar length:sizeof(unsigned char)];
	}
	
	//PROPERTIES
	NSString* sizeString = [NSString stringWithFormat:@"%dx%d", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
	const char* utfSizeString = [sizeString UTF8String];
	
	NSData* size = [NSData dataWithBytes:utfSizeString length:strlen(utfSizeString)+1];
	
	//SEPARATOR
	const char* utfSeparatorString = [separatorString UTF8String];
	
	NSData* separator = [NSData dataWithBytes:utfSeparatorString length:strlen(utfSeparatorString)+1];
	
	[mcfData appendData:size];
	[mcfData appendData:separator];
	[mcfData appendData:mData];
	
	CGImageRelease(cgImage);
	
	return mcfData;
}


- (NSData *)dataIn4BC
{
	CGImageRef cgImage = [xfImageDoc currentCGImage];
    if (cgImage==nil)
        return nil;
	
	NSMutableData* fbcData = [NSMutableData dataWithCapacity:0];
	
	NSRect bounds = NSMakeRect(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
	NSImage* image = [[NSImage alloc] initWithSize:bounds.size];
	
	[image lockFocus];
	
	CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect*)&bounds, cgImage);
    
	[image unlockFocus];
	
	NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	[image release];
	
	NSMutableData* rgbData = [NSMutableData dataWithCapacity:0];
	
	float columnWidth = 4.0f;
	float rowHeight = 8.0f;
	
	int columns = ceil(CGImageGetWidth(cgImage) / columnWidth);
	int rows = ceil(CGImageGetHeight(cgImage) / rowHeight);
	
	int gridSize = columns * rows;
	
	int i, j, k, l;
	for (i=0; i<gridSize; i++) {
		int x = fmod(i, columns) * columnWidth;
		int y = (i / columns) * rowHeight;
		
		CGFloat rHead = 0.0f;
		CGFloat rHeadOffset[(int)columnWidth][(int)rowHeight];
		CGFloat gHead = 0.0f;
		CGFloat gHeadOffset[(int)columnWidth][(int)rowHeight];
		CGFloat bHead = 0.0f;
		CGFloat bHeadOffset[(int)columnWidth][(int)rowHeight];
		
		for (j=0; j<columnWidth; j++) {
			
			NSColor* color = [bitmap colorAtX:x+j y:y];
			
			rHead += [color redComponent]*255.0f;
			gHead += [color greenComponent]*255.0f;
			bHead += [color blueComponent]*255.0f;
			
			rHeadOffset[j][0] = [color redComponent]*255.0f;
			gHeadOffset[j][0] = [color greenComponent]*255.0f;
			bHeadOffset[j][0] = [color blueComponent]*255.0f;
			
			for (k=1; k<rowHeight; k++) {
				NSColor* color = [bitmap colorAtX:x+j y:y+k];
				
				rHeadOffset[j][k] = [color redComponent]*255.0f;
				gHeadOffset[j][k] = [color greenComponent]*255.0f;
				bHeadOffset[j][k] = [color blueComponent]*255.0f;
			}
		}
		
		rHead = lround(rHead * 0.25f);
		gHead = lround(gHead * 0.25f);
		bHead = lround(bHead * 0.25f);
		
		Byte rHeadByte = (Byte)rHead;
		Byte gHeadByte = (Byte)gHead;
		Byte bHeadByte = (Byte)bHead;
		
		//NSLog(@"____ ____ ____ ____ ____ ____ ____ ____");
		//NSLog(@"rHead: %f gHead: %f bHead: %f", rHead, gHead, bHead);
		
		unsigned char* rHeadChar = (unsigned char *)&rHeadByte;
		unsigned char* gHeadChar = (unsigned char *)&gHeadByte;
		unsigned char* bHeadChar = (unsigned char *)&bHeadByte;
		
		NSMutableData* rData = [NSMutableData dataWithCapacity:0];
		NSMutableData* gData = [NSMutableData dataWithCapacity:0];
		NSMutableData* bData = [NSMutableData dataWithCapacity:0];
		
		[rData appendBytes:rHeadChar length:sizeof(unsigned char)];
		[gData appendBytes:gHeadChar length:sizeof(unsigned char)];
		[bData appendBytes:bHeadChar length:sizeof(unsigned char)];
		
		for (j=0; j<columnWidth; j++) {
			
			CGFloat rHeadCurrent = rHead;
			CGFloat gHeadCurrent = gHead;
			CGFloat bHeadCurrent = bHead;
			
			for (k=0; k<rowHeight; k++) {				
				rHeadOffset[j][k] = lround(MAX(-7, MIN(rHeadOffset[j][k] - rHeadCurrent, 8)));
				gHeadOffset[j][k] = lround(MAX(-7, MIN(gHeadOffset[j][k] - gHeadCurrent, 8)));
				bHeadOffset[j][k] = lround(MAX(-7, MIN(bHeadOffset[j][k] - bHeadCurrent, 8)));
				
				//NSLog(@"rHeadOffset: %f gHeadOffset: %f bHeadOffset: %f", rHeadOffset[j][k], gHeadOffset[j][k], bHeadOffset[j][k]);
				
				rHeadCurrent += rHeadOffset[j][k];
				gHeadCurrent += gHeadOffset[j][k];
				bHeadCurrent += bHeadOffset[j][k];
				
				//rHeadCurrent = MAX(0, MIN(rHeadCurrent, 255));
				//gHeadCurrent = MAX(0, MIN(gHeadCurrent, 255));
				//bHeadCurrent = MAX(0, MIN(bHeadCurrent, 255));
			}
		}
		
		for (j=0; j<columnWidth; j++) {
			for (k=0; k<rowHeight; k+=2) {
				Byte rb1 = (Byte)(rHeadOffset[j][k] + 7);
				Byte rb2 = (Byte)(rHeadOffset[j][k+1] + 7);
				Byte gb1 = (Byte)(gHeadOffset[j][k] + 7);
				Byte gb2 = (Byte)(gHeadOffset[j][k+1] + 7);
				Byte bb1 = (Byte)(bHeadOffset[j][k] + 7);
				Byte bb2 = (Byte)(bHeadOffset[j][k+1] + 7);
				
				unsigned char* rb1Char = (unsigned char *)&rb1;
				unsigned char* rb2Char = (unsigned char *)&rb2;
				unsigned char* gb1Char = (unsigned char *)&gb1;
				unsigned char* gb2Char = (unsigned char *)&gb2;
				unsigned char* bb1Char = (unsigned char *)&bb1;
				unsigned char* bb2Char = (unsigned char *)&bb2;
				
				for (l=0; l<4; l++) {
					if (BITOP(rb2Char, l, &)) BITOP(rb1Char, l+4, |=);
					if (BITOP(gb2Char, l, &)) BITOP(gb1Char, l+4, |=);
					if (BITOP(bb2Char, l, &)) BITOP(bb1Char, l+4, |=);
				}
				
				[rData appendBytes:rb1Char length:sizeof(unsigned char)];
				[gData appendBytes:gb1Char length:sizeof(unsigned char)];
				[bData appendBytes:bb1Char length:sizeof(unsigned char)];
			}
		}
		
		[rgbData appendData:rData];
		[rgbData appendData:gData];
		[rgbData appendData:bData];
	}
	
	//PROPERTIES
	NSString* sizeString = [NSString stringWithFormat:@"%dx%d", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
	const char* utfSizeString = [sizeString UTF8String];
	
	NSData* size = [NSData dataWithBytes:utfSizeString length:strlen(utfSizeString)+1];
	
	//SEPARATOR
	const char* utfSeparatorString = [separatorString UTF8String];
	
	NSData* separator = [NSData dataWithBytes:utfSeparatorString length:strlen(utfSeparatorString)+1];
	
	[fbcData appendData:size];
	[fbcData appendData:separator];
	[fbcData appendData:rgbData];
	
	CGImageRelease(cgImage);
	
	return fbcData;
}


- (NSData *)dataInBASCII
{
	CGImageRef cgImage = [xfImageDoc currentCGImage];
    if (cgImage==nil)
        return nil;
	
	NSMutableData* basciiData = [NSMutableData dataWithCapacity:0];
	
	NSRect bounds = NSMakeRect(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
	NSImage* image = [[NSImage alloc] initWithSize:bounds.size];
	
	[image lockFocus];
	
	CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect*)&bounds, cgImage);
    
	[image unlockFocus];
	
	NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	[image release];
	
	NSMutableData* blockData = [NSMutableData dataWithCapacity:0];
	
	float columnWidth = 8.0f;
	float rowHeight = 16.0f;
	float blockSize = columnWidth * rowHeight;
	
	int columns = ceil(CGImageGetWidth(cgImage) / columnWidth);
	int rows = ceil(CGImageGetHeight(cgImage) / rowHeight);
	
	int gridSize = columns * rows;
	
	int i, j, k;
	for (i=0; i<gridSize; i++) {
		int x = fmod(i, columns) * columnWidth;
		int y = (i / columns) * rowHeight;
		
		CGFloat red = 0.0;
		CGFloat green = 0.0;
		CGFloat blue = 0.0;
		
		for (j=0; j<columnWidth; j++) {
			for (k=0; k<rowHeight; k++) {
				NSColor* color = [bitmap colorAtX:x+j y:y+k];
				
				red += [color redComponent]*255.0;
				green += [color greenComponent]*255.0;
				blue += [color blueComponent]*255.0;
			}
		}
		
		red /= blockSize;
		green /= blockSize;
		blue /= blockSize;
		
		float key = (red + green + blue) / 3;
		
		if (key < 40) {
			[blockData appendBytes:bAscii0 length:sizeof(bAscii0)];
		} else if (key < 96) {
			[blockData appendBytes:bAscii1 length:sizeof(bAscii1)];
		} else if (key < 160) {
			[blockData appendBytes:bAscii2 length:sizeof(bAscii2)];
		} else if (key < 216) {
			[blockData appendBytes:bAscii3 length:sizeof(bAscii3)];
		} else {
			[blockData appendBytes:bAscii4 length:sizeof(bAscii4)];
		}
	}
	
	//PROPERTIES
	NSString* sizeString = [NSString stringWithFormat:@"%dx%d", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
	const char* utfSizeString = [sizeString UTF8String];
	
	NSData* size = [NSData dataWithBytes:utfSizeString length:strlen(utfSizeString)+1];
	
	//SEPARATOR
	const char* utfSeparatorString = [separatorString UTF8String];
	
	NSData* separator = [NSData dataWithBytes:utfSeparatorString length:strlen(utfSeparatorString)+1];
	
	[basciiData appendData:size];
	[basciiData appendData:separator];
	[basciiData appendData:blockData];
	
	CGImageRelease(cgImage);
	
	return basciiData;
}


- (NSData *)dataInBLINX
{
	CGImageRef cgImage = [xfImageDoc currentCGImage];
    if (cgImage==nil)
        return nil;
	
	NSMutableData* basciiData = [NSMutableData dataWithCapacity:0];
	
	NSRect bounds = NSMakeRect(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
	NSImage* image = [[NSImage alloc] initWithSize:bounds.size];
	
	[image lockFocus];
	
	CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect*)&bounds, cgImage);
    
	[image unlockFocus];
	
	NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	[image release];
	
	NSMutableData* blockData = [NSMutableData dataWithCapacity:0];
	
	float quality = [[xfImageDoc saveQuality] floatValue];
	int qualityOffset = lround((1.0f-quality)*10.0f);
	
	float columnWidth = 16.0f;
	float rowHeight = 8.0f;
	float blockSize = columnWidth * rowHeight;
	
	int columns = ceil(CGImageGetWidth(cgImage) / columnWidth);
	int rows = ceil(CGImageGetHeight(cgImage) / rowHeight);
	
	int gridSize = columns * rows;
	
	int i, j;
	for (i=0; i<gridSize; i++) {
		int x = fmod(i, columns) * columnWidth;
		int y = (i / columns) * rowHeight;
		
		NSMutableData* rHeadData = [NSMutableData dataWithCapacity:0];
		NSMutableData* rData = [NSMutableData dataWithCapacity:0];
		NSMutableData* gHeadData = [NSMutableData dataWithCapacity:0];
		NSMutableData* gData = [NSMutableData dataWithCapacity:0];
		NSMutableData* bHeadData = [NSMutableData dataWithCapacity:0];
		NSMutableData* bData = [NSMutableData dataWithCapacity:0];
		
		NSColor* color = [bitmap colorAtX:x y:y];
		CGFloat rFloat = lround(255.0f * [color redComponent]);
		CGFloat gFloat = lround(255.0f * [color greenComponent]);
		CGFloat bFloat = lround(255.0f * [color blueComponent]);		
		
		Byte rByteBuffer = (Byte)rFloat;
		Byte rByteCount = 0;
		Byte gByteBuffer = (Byte)gFloat;
		Byte gByteCount = 0;
		Byte bByteBuffer = (Byte)bFloat;
		Byte bByteCount = 0;
		
		int xOff = 1;
		int yOff = 0;
		
		int xLimit = 3;
		int yLimit = 2;
		
		BOOL xUp = NO;
		
		for (j=1; j<blockSize; j++) {
			
			NSColor* color = [bitmap colorAtX:x+xOff y:y+yOff];
			
			CGFloat rFloat = lround(255.0f * [color redComponent]);
			Byte rByte = (Byte)rFloat;
			
			if (rByte < rByteBuffer-qualityOffset || rByte > rByteBuffer+qualityOffset || rByteCount >= 255) {
				
				unsigned char* rValueChar = (unsigned char *)&rByteBuffer;
				[rData appendBytes:rValueChar length:sizeof(unsigned char)];
				
				if (rByteCount > 0) {
					
					[rData appendBytes:rValueChar length:sizeof(unsigned char)];
					
					unsigned char* rCountChar = (unsigned char *)&rByteCount;
					[rData appendBytes:rCountChar length:sizeof(unsigned char)];
				}
				
				rByteBuffer = rByte;
				rByteCount = 0;
			}
			else {
				rByteCount++;
			}
			
			
			CGFloat gFloat = lround(255.0f * [color greenComponent]);
			Byte gByte = (Byte)gFloat;
			
			if (gByte < gByteBuffer-qualityOffset || gByte > gByteBuffer+qualityOffset || gByteCount >= 255) {
				unsigned char* gValueChar = (unsigned char *)&gByteBuffer;
				[gData appendBytes:gValueChar length:sizeof(unsigned char)];
				
				if (gByteCount > 0) {
					
					[gData appendBytes:gValueChar length:sizeof(unsigned char)];
					
					unsigned char* gCountChar = (unsigned char *)&gByteCount;
					[gData appendBytes:gCountChar length:sizeof(unsigned char)];
				}
				
				gByteBuffer = gByte;
				gByteCount = 0;
			}
			else {
				gByteCount++;
			}
			
			
			CGFloat bFloat = lround(255.0f * [color blueComponent]);
			Byte bByte = (Byte)bFloat;
			
			if (bByte < bByteBuffer-qualityOffset || bByte > bByteBuffer+qualityOffset || bByteCount >= 255) {
				unsigned char* bValueChar = (unsigned char *)&bByteBuffer;
				[bData appendBytes:bValueChar length:sizeof(unsigned char)];
				
				if (bByteCount > 0) {
					
					[bData appendBytes:bValueChar length:sizeof(unsigned char)];
					
					unsigned char* bCountChar = (unsigned char *)&bByteCount;
					[bData appendBytes:bCountChar length:sizeof(unsigned char)];
				}
				
				bByteBuffer = bByte;
				bByteCount = 0;
			}
			else {
				bByteCount++;
			}
			
			
			if (j==35 || j==51 || j==67 || j==83 || j==99 || j==112 || j==121 || j==126) {
				yOff++;
			}
			
			if (j==106 || j==117 || j==124) {
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
		}
		
		unsigned char* rValueChar = (unsigned char *)&rByteBuffer;
		[rData appendBytes:rValueChar length:sizeof(unsigned char)];
		
		if (rByteCount > 0) {
			
			[rData appendBytes:rValueChar length:sizeof(unsigned char)];
			
			unsigned char* rCountChar = (unsigned char *)&rByteCount;
			[rData appendBytes:rCountChar length:sizeof(unsigned char)];
		}
		
		unsigned char* gValueChar = (unsigned char *)&gByteBuffer;
		[gData appendBytes:gValueChar length:sizeof(unsigned char)];
		
		if (gByteCount > 0) {
			
			[gData appendBytes:gValueChar length:sizeof(unsigned char)];
			
			unsigned char* gCountChar = (unsigned char *)&gByteCount;
			[gData appendBytes:gCountChar length:sizeof(unsigned char)];
		}
		
		unsigned char* bValueChar = (unsigned char *)&bByteBuffer;
		[bData appendBytes:bValueChar length:sizeof(unsigned char)];
		
		if (bByteCount > 0) {
			
			[bData appendBytes:bValueChar length:sizeof(unsigned char)];
			
			unsigned char* bCountChar = (unsigned char *)&bByteCount;
			[bData appendBytes:bCountChar length:sizeof(unsigned char)];
		}
		
		NSData* blockID = [NSData dataWithBytes:&i length:sizeof(i)];
		
		[rHeadData appendData:blockID];
		Byte rLengthByte = (Byte)[rData length];
		unsigned char* rLengthChar = (unsigned char *)&rLengthByte;
		[rHeadData appendBytes:rLengthChar length:sizeof(unsigned char)];
		
		[gHeadData appendData:blockID];
		Byte gLengthByte = (Byte)[gData length];
		unsigned char* gLengthChar = (unsigned char *)&gLengthByte;
		[gHeadData appendBytes:gLengthChar length:sizeof(unsigned char)];
		
		[bHeadData appendData:blockID];
		Byte bLengthByte = (Byte)[bData length];
		unsigned char* bLengthChar = (unsigned char *)&bLengthByte;
		[bHeadData appendBytes:bLengthChar length:sizeof(unsigned char)];
		
		[blockData appendData:rHeadData];
		[blockData appendData:rData];
		[blockData appendData:gHeadData];
		[blockData appendData:gData];
		[blockData appendData:bHeadData];
		[blockData appendData:bData];
	}
	
	//PROPERTIES
	NSString* sizeString = [NSString stringWithFormat:@"%dx%d", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
	const char* utfSizeString = [sizeString UTF8String];
	
	NSData* size = [NSData dataWithBytes:utfSizeString length:strlen(utfSizeString)+1];
	
	//SEPARATOR
	const char* utfSeparatorString = [separatorString UTF8String];
	
	NSData* separator = [NSData dataWithBytes:utfSeparatorString length:strlen(utfSeparatorString)+1];
	
	[basciiData appendData:size];
	[basciiData appendData:separator];
	[basciiData appendData:blockData];
	
	CGImageRelease(cgImage);
	
	return basciiData;
}


- (NSData *)dataInUSPEC
{
	CGImageRef cgImage = [xfImageDoc currentCGImage];
    if (cgImage==nil)
        return nil;
	
	NSMutableData* uspecData = [NSMutableData dataWithCapacity:0];
	
	NSRect bounds = NSMakeRect(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
	NSImage* image = [[NSImage alloc] initWithSize:bounds.size];
	
	[image lockFocus];
	
	CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect*)&bounds, cgImage);
    
	[image unlockFocus];
	
	NSBitmapImageRep* bitmap = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	[image release];
	
	NSMutableArray* pixelArray = [[NSMutableArray alloc] init];
	
	NSString* indexString = @"index";
	NSString* colorString = @"color";
	
	NSArray* keys = [NSArray arrayWithObjects:indexString, colorString, nil];
	
	int imageWidth = CGImageGetWidth(cgImage);
	int imageHeight = CGImageGetHeight(cgImage);
	
	int imageSize = imageWidth * imageHeight;
	
	int i;
	for (i=0; i<imageSize; i++) {
		int x = fmod(i, imageWidth);
		int y = i / imageWidth;
		
		NSColor* color = [bitmap colorAtX:x y:y];
		
		CGFloat red = [color redComponent]*255.0;
		CGFloat green = [color greenComponent]*255.0;
		CGFloat blue = [color blueComponent]*255.0;
		
		int colorInt = red + green*256 + blue*256*256;
		
		NSValue* indexValue = [NSNumber numberWithInt:i];
		NSValue* colorValue = [NSNumber numberWithInt:colorInt];
		
		NSArray* objects = [NSArray arrayWithObjects:indexValue, colorValue, nil];
		
		[pixelArray addObject:[NSDictionary dictionaryWithObjects:objects forKeys:keys]];
	}
	NSSortDescriptor * sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"color" ascending:YES] autorelease];
	[pixelArray sortUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
	
	NSMutableData* sortedData = [NSMutableData dataWithCapacity:0];
	
	for (i=0; i<imageSize; i++) {
		NSDictionary* objects = [pixelArray objectAtIndex:i];
		NSValue* colorValue = [objects valueForKey:@"index"];
		int colorInt;
		[colorValue getValue:&colorInt];		
		[sortedData appendData:[NSData dataWithBytes:&colorInt length:sizeof(colorInt)]];
	}
	
	//PROPERTIES
	NSString* sizeString = [NSString stringWithFormat:@"%dx%d", CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)];
	const char* utfSizeString = [sizeString UTF8String];
	
	NSData* size = [NSData dataWithBytes:utfSizeString length:strlen(utfSizeString)+1];
	
	//SEPARATOR
	const char* utfSeparatorString = [separatorString UTF8String];
	
	NSData* separator = [NSData dataWithBytes:utfSeparatorString length:strlen(utfSeparatorString)+1];
	
	[uspecData appendData:size];
	[uspecData appendData:separator];
	[uspecData appendData:sortedData];
	
	CGImageRelease(cgImage);
	
	return uspecData;
}


@end
