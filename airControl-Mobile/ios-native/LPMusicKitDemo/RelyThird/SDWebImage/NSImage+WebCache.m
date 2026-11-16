#import "NSImage+WebCache.h"
#if SD_MAC
@implementation NSImage (WebCache)
- (CGImageRef)CGImage {
    NSRect imageRect = NSMakeRect(0, 0, self.size.width, self.size.height);
    CGImageRef cgImage = [self CGImageForProposedRect:&imageRect context:NULL hints:nil];
    return cgImage;
}
- (NSArray<NSImage *> *)images {
    return nil;
}
- (BOOL)isGIF {
    BOOL isGIF = NO;
    for (NSImageRep *rep in self.representations) {
        if ([rep isKindOfClass:[NSBitmapImageRep class]]) {
            NSBitmapImageRep *bitmapRep = (NSBitmapImageRep *)rep;
            NSUInteger frameCount = [[bitmapRep valueForProperty:NSImageFrameCount] unsignedIntegerValue];
            isGIF = frameCount > 1 ? YES : NO;
            break;
        }
    }
    return isGIF;
}
@end
#endif
