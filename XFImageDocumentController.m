//
//  XFImageDocumentController.m
//  ExtraFile
//
//  Created by Kim Asendorf on 06.05.11.
//

#import "XFImageDocumentController.h"


static NSString* ImageIOLocalizedString(NSString* key)
{
    static NSBundle* b = nil;
    
    if (b == nil)
        b = [NSBundle bundleWithIdentifier:@"com.apple.ImageIO.framework"];
	
    return [b localizedStringForKey:key value:key table: @"CGImageSource"];
}


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


@implementation XFImageDocumentController


- (NSString *)defaultType
{
    return @"public.tiff";
}


- (NSArray *)documentClassNames
{
    return [NSArray arrayWithObject:@"XFImageDocument"];
}


- (Class)documentClassForType:(NSString *)typeName
{
    return [[NSBundle mainBundle] classNamed:@"XFImageDocument"];
}


- (NSString *)displayNameForType:(NSString *)typeName;
{	
	NSString* displayName = nil;
	if ([typeName rangeOfString:XFTypeNameRoot].location != NSNotFound) {
		displayName = XFIOLocalizedString(typeName);
	} else {
		displayName = ImageIOLocalizedString(typeName);
	}
    return displayName;
}


// Return the name of the document type that should be used when opening a URL
// In this app, we return the UTI type returned by CGImageSourceGetType.
//
/*
- (NSString *)typeForContentsOfURL:(NSURL *)absURL error:(NSError **)outError
{
	NSLog(@"TYPE CONTENT URL");
	NSLog(@"%@", absURL);
	
    NSString* type = nil;
	CGImageSourceRef isrc = CGImageSourceCreateWithURL((CFURLRef)absURL, nil);
	NSLog(@"%@", isrc);
	
	if (isrc)
	{
		NSLog(@"TYPE CGI");
		type = [[(NSString *)CGImageSourceGetType(isrc) retain] autorelease];
		NSLog(@"%@", type);
		CFRelease(isrc);
	}
	
    return type;
}
*/


// Given a document type, return an array of corresponding file name extensions 
// and HFS file type strings of the sort returned by NSFileTypeForHFSTypeCode().
// In this app, 'typeName' is a UTI type so we can call UTTypeCopyDeclaration().
//

- (NSArray *)fileExtensionsFromType:(NSString *)typeName;
{	
    NSArray* readExts = nil;
    
    CFDictionaryRef utiDecl = UTTypeCopyDeclaration((CFStringRef)typeName);
    if (utiDecl)
    {
        CFDictionaryRef utiSpec = CFDictionaryGetValue(utiDecl, kUTTypeTagSpecificationKey);
        if (utiSpec)
        {
            CFTypeRef  ext = CFDictionaryGetValue(utiSpec, kUTTagClassFilenameExtension);
			
            if (ext && CFGetTypeID(ext) == CFStringGetTypeID())
                readExts = [NSArray arrayWithObject:(id)ext];
            if (ext && CFGetTypeID(ext) == CFArrayGetTypeID())
                readExts = [NSArray arrayWithArray:(id)ext];
        }
        CFRelease(utiDecl);
    }
    
    return readExts;
}

@end
