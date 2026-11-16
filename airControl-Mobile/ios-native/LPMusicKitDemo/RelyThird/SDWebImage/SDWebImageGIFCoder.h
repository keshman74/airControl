#import <Foundation/Foundation.h>
#import "SDWebImageCoder.h"
@interface SDWebImageGIFCoder : NSObject <SDWebImageCoder>
+ (nonnull instancetype)sharedCoder;
@end
