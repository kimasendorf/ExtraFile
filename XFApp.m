//
//  XFApp.m
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import "XFApp.h"
#import "XFImageDocumentController.h"
#import "XFProfile.h"


static BOOL automaticReload;
static BOOL cleanBuffer;
static NSColor* backgroundColor;


@implementation XFApp

- (id)init
{
    [[XFImageDocumentController alloc] init];
	
    self = [super init];
    [self setDelegate:self];	
    return self;
}


- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSColor* defaultColor = [defaults objectForKey:@"DefaultBackgroundColor"];
    if (defaultColor == nil) {
		[xfBackgroundColorWell setColor:[NSColor colorWithCalibratedRed:0.5f green:0.5f blue:0.5f alpha:1.0f]];
	}
	backgroundColor = [xfBackgroundColorWell color];
	
	NSNumber* ar = [defaults objectForKey:@"DefaultReload"];
	if (ar == nil) {
		automaticReload = YES;
	} else {
		automaticReload = [defaults boolForKey:@"DefaultReload"];
	}
	[xfReloadCheckBox setState:automaticReload];
	
	NSNumber* cb = [defaults objectForKey:@"DefaultBuffer"];
	if (cb == nil) {
		cleanBuffer = YES;
	} else {
		cleanBuffer = [defaults boolForKey:@"DefaultBuffer"];
	}
	[xfBufferCheckBox setState:cleanBuffer];
	
	NSNumber* extn = [defaults objectForKey:@"NSNavLastUserSetHideExtensionButtonState"];
	if(extn == nil) {
		[defaults setBool:NO forKey:@"NSNavLastUserSetHideExtensionButtonState"];
	}
	
	[defaults synchronize];
}


- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)theApp
{
    return NO;
}


#pragma mark #### Preferences

- (IBAction)changeAutomaticReload:(id)sender
{
	automaticReload = [sender state];
	[[[NSDocumentController sharedDocumentController] currentDocument]
	 performSelector:@selector(changeAutomaticReload:) withObject:sender
	 afterDelay:0];
}


+ (BOOL)getAutomaticReload
{
	return automaticReload;
}


- (IBAction)changeCleanBuffer:(id)sender
{
	cleanBuffer = [sender state];
	[[[NSDocumentController sharedDocumentController] currentDocument]
	 performSelector:@selector(changeCleanBuffer:) withObject:sender
	 afterDelay:0];
}


+ (BOOL)getCleanBuffer
{
	return cleanBuffer;
}


- (IBAction)changeBackgroundColor:(id)sender
{
	backgroundColor = [sender color];
	[[[NSDocumentController sharedDocumentController] currentDocument]
	 performSelector:@selector(changeBackgroundColor:) withObject:sender
	 afterDelay:0];
}


+ (NSColor *)getBackgroundColor
{
	return backgroundColor;
}


#pragma mark -

- (NSArray *)RGBProfiles
{
    return [XFProfile arrayOfAllProfilesWithSpace:cmRGBData];
}


- (NSArray *)GrayProfiles
{
    return [XFProfile arrayOfAllProfilesWithSpace:cmGrayData];
}


- (NSArray *)CMYKProfiles
{
    return [XFProfile arrayOfAllProfilesWithSpace:cmCMYKData];
}


@end
