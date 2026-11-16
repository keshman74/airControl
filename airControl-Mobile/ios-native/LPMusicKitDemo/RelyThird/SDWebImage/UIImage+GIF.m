#import "UIImage+GIF.h"
#import "SDWebImageGIFCoder.h"
#import "NSImage+WebCache.h"
@implementation UIImage (GIF)
+ (UIImage *)sd_animatedGIFWithData:(NSData *)data {
    if (!data) {
        return nil;
    }
    return [[SDWebImageGIFCoder sharedCoder] decodedImageWithData:data];
}
- (BOOL)isGIF {
    return (self.images != nil);
}
@end
