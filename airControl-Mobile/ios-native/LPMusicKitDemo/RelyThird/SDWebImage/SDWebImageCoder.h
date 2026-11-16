#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
#import "NSData+ImageContentType.h"
FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageCoderScaleDownLargeImagesKey;
CG_EXTERN CGColorSpaceRef _Nonnull SDCGColorSpaceGetDeviceRGB(void);
CG_EXTERN BOOL SDCGImageRefContainsAlpha(_Nullable CGImageRef imageRef);
@protocol SDWebImageCoder <NSObject>
@required
#pragma mark - Decoding
- (BOOL)canDecodeFromData:(nullable NSData *)data;
- (nullable UIImage *)decodedImageWithData:(nullable NSData *)data;
- (nullable UIImage *)decompressedImageWithImage:(nullable UIImage *)image
                                            data:(NSData * _Nullable * _Nonnull)data
                                         options:(nullable NSDictionary<NSString*, NSObject*>*)optionsDict;
#pragma mark - Encoding
- (BOOL)canEncodeToFormat:(SDImageFormat)format;
- (nullable NSData *)encodedDataWithImage:(nullable UIImage *)image format:(SDImageFormat)format;
@end
@protocol SDWebImageProgressiveCoder <SDWebImageCoder>
@required
- (BOOL)canIncrementallyDecodeFromData:(nullable NSData *)data;
- (nullable UIImage *)incrementallyDecodedImageWithData:(nullable NSData *)data finished:(BOOL)finished;
@end
