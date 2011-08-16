//
//  XFImageDocument.h
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>

#import "XFProfile.h"
#import "XFImageView.h"
#import "XFImageFilter.h"
#import "XFZoomScrollView.h"


@class XFImageView, XFZoomScrollView;

@interface XFImageDocument : NSDocument <NSWindowDelegate>
{
	IBOutlet XFImageView*			xfImageView;
	IBOutlet XFZoomScrollView*		xfZoomScrollView;
    IBOutlet NSSlider*				xfExposureSlider;
    IBOutlet NSSlider*				xfSaturationSlider;
    IBOutlet NSPopUpButton*			xfProfilePopup;
	
    IBOutlet NSView*				xfSavePanelView;
    NSString*						xfSaveUTI;
    CFMutableDictionaryRef			xfSaveMetaAndOpts;
	
	IBOutlet NSPanel*				xfProgressPanel;
	IBOutlet NSProgressIndicator*	xfProgressIndicator;
	IBOutlet NSTextField*			xfProgressStatus;
	
    CGImageRef						xfImage;
    CFDictionaryRef					xfMetadata;
    XFImageFilter*					xfFilteredImage;
	
    NSArray*						xfProfiles;
	
    NSNumber*						xfSwitchValue;	
    XFProfile*						xfProfileValue;
    NSNumber*						xfExposureValue;	
    NSNumber*						xfSaturationValue;
	
    NSPrintInfo*					xfPrintInfo;
	
	CGFloat							_zoomFactor;
	BOOL							automaticReload;
	BOOL							cleanBuffer;
	NSColor*						backgroundColor;
}

- (CGAffineTransform)imageTransform;
- (CIImage *)currentCIImageWithTransform:(CGAffineTransform)ctm;
- (CGImageRef)currentCGImage;
- (CGSize)imageSize;
- (CGFloat)zoomFactor;
- (NSRect)visibleRect;

- (NSNumber *)saveQuality;

- (void)setupAll;
- (void)setupExposure;
- (void)setupSaturation;

- (BOOL)switchState;

- (IBAction)reload:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

- (IBAction)changeAutomaticReload:(id)sender;
- (IBAction)changeCleanBuffer:(id)sender;
- (IBAction)changeBackgroundColor:(id)sender;
- (void)setBackgroundColor:(NSColor *)color;

@end
