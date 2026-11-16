#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
@interface SDImageCacheConfig : NSObject
@property (assign, nonatomic) BOOL shouldDecompressImages;
@property (assign, nonatomic) BOOL shouldDisableiCloud;
@property (assign, nonatomic) BOOL shouldCacheImagesInMemory;
@property (assign, nonatomic) NSDataReadingOptions diskCacheReadingOptions;
@property (assign, nonatomic) NSDataWritingOptions diskCacheWritingOptions;
@property (assign, nonatomic) NSInteger maxCacheAge;
@property (assign, nonatomic) NSUInteger maxCacheSize;
@end
