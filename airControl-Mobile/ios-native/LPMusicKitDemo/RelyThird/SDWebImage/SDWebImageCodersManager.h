#import <Foundation/Foundation.h>
#import "SDWebImageCoder.h"
@interface SDWebImageCodersManager : NSObject<SDWebImageCoder>
+ (nonnull instancetype)sharedInstance;
@property (nonatomic, strong, readwrite, nullable) NSArray<SDWebImageCoder>* coders;
- (void)addCoder:(nonnull id<SDWebImageCoder>)coder;
- (void)removeCoder:(nonnull id<SDWebImageCoder>)coder;
@end
