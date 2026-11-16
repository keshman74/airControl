#import "SDWebImageFrame.h"
@interface SDWebImageFrame ()
@property (nonatomic, strong, readwrite, nonnull) UIImage *image;
@property (nonatomic, readwrite, assign) NSTimeInterval duration;
@end
@implementation SDWebImageFrame
+ (instancetype)frameWithImage:(UIImage *)image duration:(NSTimeInterval)duration {
    SDWebImageFrame *frame = [[SDWebImageFrame alloc] init];
    frame.image = image;
    frame.duration = duration;
    return frame;
}
@end
