#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
@interface SDWebImageFrame : NSObject
@property (nonatomic, strong, readonly, nonnull) UIImage *image;
@property (nonatomic, readonly, assign) NSTimeInterval duration;
+ (instancetype _Nonnull)frameWithImage:(UIImage * _Nonnull)image duration:(NSTimeInterval)duration;
@end
