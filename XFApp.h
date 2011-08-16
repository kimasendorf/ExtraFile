/*
 
 ExtraFile
 http://extrafile.org
 
*/

//
//  XFApp.h
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import <AppKit/AppKit.h>


@interface XFApp : NSApplication <NSApplicationDelegate>
{
	IBOutlet NSButton* xfReloadCheckBox;
	IBOutlet NSButton* xfBufferCheckBox;
	IBOutlet NSColorWell* xfBackgroundColorWell;
}

- (IBAction)changeAutomaticReload:(id)sender;
- (IBAction)changeCleanBuffer:(id)sender;
- (IBAction)changeBackgroundColor:(id)sender;

+ (BOOL)getAutomaticReload;
+ (BOOL)getCleanBuffer;
+ (NSColor *)getBackgroundColor;

@end
