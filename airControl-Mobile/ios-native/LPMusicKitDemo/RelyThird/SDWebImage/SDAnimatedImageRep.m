#import "SDAnimatedImageRep.h"
#if SD_MAC
#import "SDWebImageGIFCoder.h"
@interface SDWebImageGIFCoder ()
- (float)sd_frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source;
@end
@interface SDAnimatedImageRep ()
@property (nonatomic, assign, readonly, nullable) CGImageSourceRef imageSource;
@end
@implementation SDAnimatedImageRep
- (void)setProperty:(NSBitmapImageRepPropertyKey)property withValue:(id)value {
    [super setProperty:property withValue:value];
    if ([property isEqualToString:NSImageCurrentFrame]) {
        CGImageSourceRef imageSource = self.imageSource;
        if (!imageSource) {
            return;
        }
        CFStringRef type = CGImageSourceGetType(imageSource);
        if (!type) {
            return;
        }
        NSUInteger index = [value unsignedIntegerValue];
        float frameDuration = 0;
        if (CFStringCompare(type, kUTTypeGIF, 0) == kCFCompareEqualTo) {
            frameDuration = [[SDWebImageGIFCoder sharedCoder] sd_frameDurationAtIndex:index source:imageSource];
        }
        if (!frameDuration) {
            return;
        }
        [super setProperty:NSImageCurrentFrameDuration withValue:@(frameDuration)];
    }
}
- (CGImageSourceRef)imageSource {
    if (_tiffData) {
        return (__bridge CGImageSourceRef)(_tiffData);
    }
    return NULL;
}
@end
#endif
