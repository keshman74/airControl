#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
typedef NS_ENUM(NSInteger, SDImageFormat) {
    SDImageFormatUndefined = -1,
    SDImageFormatJPEG = 0,
    SDImageFormatPNG,
    SDImageFormatGIF,
    SDImageFormatTIFF,
    SDImageFormatWebP,
    SDImageFormatHEIC
};
@interface NSData (ImageContentType)
+ (SDImageFormat)sd_imageFormatForImageData:(nullable NSData *)data;
+ (nonnull CFStringRef)sd_UTTypeFromSDImageFormat:(SDImageFormat)format;
@end
