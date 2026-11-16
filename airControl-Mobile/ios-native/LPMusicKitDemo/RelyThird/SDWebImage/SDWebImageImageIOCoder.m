#import "SDWebImageImageIOCoder.h"
#import "SDWebImageCoderHelper.h"
#import "NSImage+WebCache.h"
#import <ImageIO/ImageIO.h>
#import "NSData+ImageContentType.h"
#if SD_UIKIT || SD_WATCH
static const size_t kBytesPerPixel = 4;
static const size_t kBitsPerComponent = 8;
static const CGFloat kDestImageSizeMB = 60.0f;
static const CGFloat kSourceImageTileSizeMB = 20.0f;
static const CGFloat kBytesPerMB = 1024.0f * 1024.0f;
static const CGFloat kPixelsPerMB = kBytesPerMB / kBytesPerPixel;
static const CGFloat kDestTotalPixels = kDestImageSizeMB * kPixelsPerMB;
static const CGFloat kTileTotalPixels = kSourceImageTileSizeMB * kPixelsPerMB;
static const CGFloat kDestSeemOverlap = 2.0f;   
#endif
@implementation SDWebImageImageIOCoder {
        size_t _width, _height;
#if SD_UIKIT || SD_WATCH
        UIImageOrientation _orientation;
#endif
        CGImageSourceRef _imageSource;
}
- (void)dealloc {
    if (_imageSource) {
        CFRelease(_imageSource);
        _imageSource = NULL;
    }
}
+ (instancetype)sharedCoder {
    static SDWebImageImageIOCoder *coder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        coder = [[SDWebImageImageIOCoder alloc] init];
    });
    return coder;
}
#pragma mark - Decode
- (BOOL)canDecodeFromData:(nullable NSData *)data {
    switch ([NSData sd_imageFormatForImageData:data]) {
        case SDImageFormatWebP:
            return NO;
        case SDImageFormatHEIC:
            return [[self class] canDecodeFromHEICFormat];
        default:
            return YES;
    }
}
- (BOOL)canIncrementallyDecodeFromData:(NSData *)data {
    switch ([NSData sd_imageFormatForImageData:data]) {
        case SDImageFormatWebP:
            return NO;
        case SDImageFormatHEIC:
            return [[self class] canDecodeFromHEICFormat];
        default:
            return YES;
    }
}
- (UIImage *)decodedImageWithData:(NSData *)data {
    if (!data) {
        return nil;
    }
    UIImage *image = [[UIImage alloc] initWithData:data];
#if SD_MAC
    return image;
#else
    if (!image) {
        return nil;
    }
    UIImageOrientation orientation = [[self class] sd_imageOrientationFromImageData:data];
    if (orientation != UIImageOrientationUp) {
        image = [[UIImage alloc] initWithCGImage:image.CGImage scale:image.scale orientation:orientation];
    }
    return image;
#endif
}
- (UIImage *)incrementallyDecodedImageWithData:(NSData *)data finished:(BOOL)finished {
    if (!_imageSource) {
        _imageSource = CGImageSourceCreateIncremental(NULL);
    }
    UIImage *image;
    CGImageSourceUpdateData(_imageSource, (__bridge CFDataRef)data, finished);
    if (_width + _height == 0) {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(_imageSource, 0, NULL);
        if (properties) {
            NSInteger orientationValue = 1;
            CFTypeRef val = CFDictionaryGetValue(properties, kCGImagePropertyPixelHeight);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_height);
            val = CFDictionaryGetValue(properties, kCGImagePropertyPixelWidth);
            if (val) CFNumberGetValue(val, kCFNumberLongType, &_width);
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) CFNumberGetValue(val, kCFNumberNSIntegerType, &orientationValue);
            CFRelease(properties);
#if SD_UIKIT || SD_WATCH
            _orientation = [SDWebImageCoderHelper imageOrientationFromEXIFOrientation:orientationValue];
#endif
        }
    }
    if (_width + _height > 0) {
        CGImageRef partialImageRef = CGImageSourceCreateImageAtIndex(_imageSource, 0, NULL);
#if SD_UIKIT || SD_WATCH
        if (partialImageRef) {
            const size_t partialHeight = CGImageGetHeight(partialImageRef);
            CGColorSpaceRef colorSpace = SDCGColorSpaceGetDeviceRGB();
            CGContextRef bmContext = CGBitmapContextCreate(NULL, _width, _height, 8, 0, colorSpace, kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
            if (bmContext) {
                CGContextDrawImage(bmContext, (CGRect){.origin.x = 0.0f, .origin.y = 0.0f, .size.width = _width, .size.height = partialHeight}, partialImageRef);
                CGImageRelease(partialImageRef);
                partialImageRef = CGBitmapContextCreateImage(bmContext);
                CGContextRelease(bmContext);
            }
            else {
                CGImageRelease(partialImageRef);
                partialImageRef = nil;
            }
        }
#endif
        if (partialImageRef) {
#if SD_UIKIT || SD_WATCH
            image = [[UIImage alloc] initWithCGImage:partialImageRef scale:1 orientation:_orientation];
#elif SD_MAC
            image = [[UIImage alloc] initWithCGImage:partialImageRef size:NSZeroSize];
#endif
            CGImageRelease(partialImageRef);
        }
    }
    if (finished) {
        if (_imageSource) {
            CFRelease(_imageSource);
            _imageSource = NULL;
        }
    }
    return image;
}
- (UIImage *)decompressedImageWithImage:(UIImage *)image
                                   data:(NSData *__autoreleasing  _Nullable *)data
                                options:(nullable NSDictionary<NSString*, NSObject*>*)optionsDict {
#if SD_MAC
    return image;
#endif
#if SD_UIKIT || SD_WATCH
    BOOL shouldScaleDown = NO;
    if (optionsDict != nil) {
        NSNumber *scaleDownLargeImagesOption = nil;
        if ([optionsDict[SDWebImageCoderScaleDownLargeImagesKey] isKindOfClass:[NSNumber class]]) {
            scaleDownLargeImagesOption = (NSNumber *)optionsDict[SDWebImageCoderScaleDownLargeImagesKey];
        }
        if (scaleDownLargeImagesOption != nil) {
            shouldScaleDown = [scaleDownLargeImagesOption boolValue];
        }
    }
    if (!shouldScaleDown) {
        return [self sd_decompressedImageWithImage:image];
    } else {
        UIImage *scaledDownImage = [self sd_decompressedAndScaledDownImageWithImage:image];
        if (scaledDownImage && !CGSizeEqualToSize(scaledDownImage.size, image.size)) {
            SDImageFormat format = [NSData sd_imageFormatForImageData:*data];
            NSData *imageData = [self encodedDataWithImage:scaledDownImage format:format];
            if (imageData) {
                *data = imageData;
            }
        }
        return scaledDownImage;
    }
#endif
}
#if SD_UIKIT || SD_WATCH
- (nullable UIImage *)sd_decompressedImageWithImage:(nullable UIImage *)image {
    if (![[self class] shouldDecodeImage:image]) {
        return image;
    }
    @autoreleasepool{
        CGImageRef imageRef = image.CGImage;
        CGColorSpaceRef colorspaceRef = [[self class] colorSpaceForImageRef:imageRef];
        size_t width = CGImageGetWidth(imageRef);
        size_t height = CGImageGetHeight(imageRef);
        CGContextRef context = CGBitmapContextCreate(NULL,
                                                     width,
                                                     height,
                                                     kBitsPerComponent,
                                                     0,
                                                     colorspaceRef,
                                                     kCGBitmapByteOrderDefault|kCGImageAlphaNoneSkipLast);
        if (context == NULL) {
            return image;
        }
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGImageRef imageRefWithoutAlpha = CGBitmapContextCreateImage(context);
        UIImage *imageWithoutAlpha = [[UIImage alloc] initWithCGImage:imageRefWithoutAlpha scale:image.scale orientation:image.imageOrientation];
        CGContextRelease(context);
        CGImageRelease(imageRefWithoutAlpha);
        return imageWithoutAlpha;
    }
}
- (nullable UIImage *)sd_decompressedAndScaledDownImageWithImage:(nullable UIImage *)image {
    if (![[self class] shouldDecodeImage:image]) {
        return image;
    }
    if (![[self class] shouldScaleDownImage:image]) {
        return [self sd_decompressedImageWithImage:image];
    }
    CGContextRef destContext;
    @autoreleasepool {
        CGImageRef sourceImageRef = image.CGImage;
        CGSize sourceResolution = CGSizeZero;
        sourceResolution.width = CGImageGetWidth(sourceImageRef);
        sourceResolution.height = CGImageGetHeight(sourceImageRef);
        float sourceTotalPixels = sourceResolution.width * sourceResolution.height;
        float imageScale = kDestTotalPixels / sourceTotalPixels;
        CGSize destResolution = CGSizeZero;
        destResolution.width = (int)(sourceResolution.width*imageScale);
        destResolution.height = (int)(sourceResolution.height*imageScale);
        CGColorSpaceRef colorspaceRef = [[self class] colorSpaceForImageRef:sourceImageRef];
        destContext = CGBitmapContextCreate(NULL,
                                            destResolution.width,
                                            destResolution.height,
                                            kBitsPerComponent,
                                            0,
                                            colorspaceRef,
                                            kCGBitmapByteOrderDefault|kCGImageAlphaNoneSkipLast);
        if (destContext == NULL) {
            return image;
        }
        CGContextSetInterpolationQuality(destContext, kCGInterpolationHigh);
        CGRect sourceTile = CGRectZero;
        sourceTile.size.width = sourceResolution.width;
        sourceTile.size.height = (int)(kTileTotalPixels / sourceTile.size.width );
        sourceTile.origin.x = 0.0f;
        CGRect destTile;
        destTile.size.width = destResolution.width;
        destTile.size.height = sourceTile.size.height * imageScale;
        destTile.origin.x = 0.0f;
        float sourceSeemOverlap = (int)((kDestSeemOverlap/destResolution.height)*sourceResolution.height);
        CGImageRef sourceTileImageRef;
        int iterations = (int)( sourceResolution.height / sourceTile.size.height );
        int remainder = (int)sourceResolution.height % (int)sourceTile.size.height;
        if(remainder) {
            iterations++;
        }
        float sourceTileHeightMinusOverlap = sourceTile.size.height;
        sourceTile.size.height += sourceSeemOverlap;
        destTile.size.height += kDestSeemOverlap;
        for( int y = 0; y < iterations; ++y ) {
            @autoreleasepool {
                sourceTile.origin.y = y * sourceTileHeightMinusOverlap + sourceSeemOverlap;
                destTile.origin.y = destResolution.height - (( y + 1 ) * sourceTileHeightMinusOverlap * imageScale + kDestSeemOverlap);
                sourceTileImageRef = CGImageCreateWithImageInRect( sourceImageRef, sourceTile );
                if( y == iterations - 1 && remainder ) {
                    float dify = destTile.size.height;
                    destTile.size.height = CGImageGetHeight( sourceTileImageRef ) * imageScale;
                    dify -= destTile.size.height;
                    destTile.origin.y += dify;
                }
                CGContextDrawImage( destContext, destTile, sourceTileImageRef );
                CGImageRelease( sourceTileImageRef );
            }
        }
        CGImageRef destImageRef = CGBitmapContextCreateImage(destContext);
        CGContextRelease(destContext);
        if (destImageRef == NULL) {
            return image;
        }
        UIImage *destImage = [[UIImage alloc] initWithCGImage:destImageRef scale:image.scale orientation:image.imageOrientation];
        CGImageRelease(destImageRef);
        if (destImage == nil) {
            return image;
        }
        return destImage;
    }
}
#endif
#pragma mark - Encode
- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    switch (format) {
        case SDImageFormatWebP:
            return NO;
        case SDImageFormatHEIC:
            return [[self class] canEncodeToHEICFormat];
        default:
            return YES;
    }
}
- (NSData *)encodedDataWithImage:(UIImage *)image format:(SDImageFormat)format {
    if (!image) {
        return nil;
    }
    if (format == SDImageFormatUndefined) {
        BOOL hasAlpha = SDCGImageRefContainsAlpha(image.CGImage);
        if (hasAlpha) {
            format = SDImageFormatPNG;
        } else {
            format = SDImageFormatJPEG;
        }
    }
    NSMutableData *imageData = [NSMutableData data];
    CFStringRef imageUTType = [NSData sd_UTTypeFromSDImageFormat:format];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, 1, NULL);
    if (!imageDestination) {
        return nil;
    }
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
#if SD_UIKIT || SD_WATCH
    NSInteger exifOrientation = [SDWebImageCoderHelper exifOrientationFromImageOrientation:image.imageOrientation];
    [properties setValue:@(exifOrientation) forKey:(__bridge_transfer NSString *)kCGImagePropertyOrientation];
#endif
    CGImageDestinationAddImage(imageDestination, image.CGImage, (__bridge CFDictionaryRef)properties);
    if (CGImageDestinationFinalize(imageDestination) == NO) {
        imageData = nil;
    }
    CFRelease(imageDestination);
    return [imageData copy];
}
#pragma mark - Helper
+ (BOOL)shouldDecodeImage:(nullable UIImage *)image {
    if (image == nil) {
        return NO;
    }
    if (image.images != nil) {
        return NO;
    }
    CGImageRef imageRef = image.CGImage;
    BOOL hasAlpha = SDCGImageRefContainsAlpha(imageRef);
    if (hasAlpha) {
        return NO;
    }
    return YES;
}
+ (BOOL)canDecodeFromHEICFormat {
    static BOOL canDecode = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
#if TARGET_OS_SIMULATOR || SD_WATCH
        canDecode = NO;
#elif SD_MAC
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        if ([processInfo respondsToSelector:@selector(operatingSystemVersion)]) {
            canDecode = processInfo.operatingSystemVersion.minorVersion >= 13;
        } else {
            canDecode = NO;
        }
#elif SD_UIKIT
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        if ([processInfo respondsToSelector:@selector(operatingSystemVersion)]) {
            canDecode = processInfo.operatingSystemVersion.majorVersion >= 11;
        } else {
            canDecode = NO;
        }
#endif
#pragma clang diagnostic pop
    });
    return canDecode;
}
+ (BOOL)canEncodeToHEICFormat {
    static BOOL canEncode = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableData *imageData = [NSMutableData data];
        CFStringRef imageUTType = [NSData sd_UTTypeFromSDImageFormat:SDImageFormatHEIC];
        CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, imageUTType, 1, NULL);
        if (!imageDestination) {
            canEncode = NO;
        } else {
            CFRelease(imageDestination);
            canEncode = YES;
        }
    });
    return canEncode;
}
#if SD_UIKIT || SD_WATCH
#pragma mark EXIF orientation tag converter
+ (UIImageOrientation)sd_imageOrientationFromImageData:(nonnull NSData *)imageData {
    UIImageOrientation result = UIImageOrientationUp;
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    if (imageSource) {
        CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL);
        if (properties) {
            CFTypeRef val;
            NSInteger exifOrientation;
            val = CFDictionaryGetValue(properties, kCGImagePropertyOrientation);
            if (val) {
                CFNumberGetValue(val, kCFNumberNSIntegerType, &exifOrientation);
                result = [SDWebImageCoderHelper imageOrientationFromEXIFOrientation:exifOrientation];
            } 
            CFRelease((CFTypeRef) properties);
        } else {
        }
        CFRelease(imageSource);
    }
    return result;
}
#endif
#if SD_UIKIT || SD_WATCH
+ (BOOL)shouldScaleDownImage:(nonnull UIImage *)image {
    BOOL shouldScaleDown = YES;
    CGImageRef sourceImageRef = image.CGImage;
    CGSize sourceResolution = CGSizeZero;
    sourceResolution.width = CGImageGetWidth(sourceImageRef);
    sourceResolution.height = CGImageGetHeight(sourceImageRef);
    float sourceTotalPixels = sourceResolution.width * sourceResolution.height;
    float imageScale = kDestTotalPixels / sourceTotalPixels;
    if (imageScale < 1) {
        shouldScaleDown = YES;
    } else {
        shouldScaleDown = NO;
    }
    return shouldScaleDown;
}
+ (CGColorSpaceRef)colorSpaceForImageRef:(CGImageRef)imageRef {
    CGColorSpaceModel imageColorSpaceModel = CGColorSpaceGetModel(CGImageGetColorSpace(imageRef));
    CGColorSpaceRef colorspaceRef = CGImageGetColorSpace(imageRef);
    BOOL unsupportedColorSpace = (imageColorSpaceModel == kCGColorSpaceModelUnknown ||
                                  imageColorSpaceModel == kCGColorSpaceModelMonochrome ||
                                  imageColorSpaceModel == kCGColorSpaceModelCMYK ||
                                  imageColorSpaceModel == kCGColorSpaceModelIndexed);
    if (unsupportedColorSpace) {
        colorspaceRef = SDCGColorSpaceGetDeviceRGB();
    }
    return colorspaceRef;
}
#endif
@end
