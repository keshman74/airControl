#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
#import "SDWebImageFrame.h"
@interface SDWebImageCoderHelper : NSObject
+ (UIImage * _Nullable)animatedImageWithFrames:(NSArray<SDWebImageFrame *> * _Nullable)frames;
+ (NSArray<SDWebImageFrame *> * _Nullable)framesFromAnimatedImage:(UIImage * _Nullable)animatedImage;
#if SD_UIKIT || SD_WATCH
+ (UIImageOrientation)imageOrientationFromEXIFOrientation:(NSInteger)exifOrientation;
+ (NSInteger)exifOrientationFromImageOrientation:(UIImageOrientation)imageOrientation;
#endif
@end
