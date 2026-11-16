#import <Foundation/Foundation.h>
#import "SDWebImageCoder.h"
@interface SDWebImageImageIOCoder : NSObject <SDWebImageProgressiveCoder>
+ (nonnull instancetype)sharedCoder;
@end
