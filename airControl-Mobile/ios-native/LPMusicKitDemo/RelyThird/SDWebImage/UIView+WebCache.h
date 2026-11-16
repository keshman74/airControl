#import "SDWebImageCompat.h"
#if SD_UIKIT || SD_MAC
#import "SDWebImageManager.h"
#import "SDWebImageTransition.h"
FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageInternalSetImageGroupKey;
FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageExternalCustomManagerKey;
FOUNDATION_EXPORT const int64_t SDWebImageProgressUnitCountUnknown; 
typedef void(^SDSetImageBlock)(UIImage * _Nullable image, NSData * _Nullable imageData);
@interface UIView (WebCache)
- (nullable NSURL *)sd_imageURL;
@property (nonatomic, strong, null_resettable) NSProgress *sd_imageProgress;
- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock;
- (void)sd_internalSetImageWithURL:(nullable NSURL *)url
                  placeholderImage:(nullable UIImage *)placeholder
                           options:(SDWebImageOptions)options
                      operationKey:(nullable NSString *)operationKey
                     setImageBlock:(nullable SDSetImageBlock)setImageBlock
                          progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                         completed:(nullable SDExternalCompletionBlock)completedBlock
                           context:(nullable NSDictionary<NSString *, id> *)context;
- (void)sd_cancelCurrentImageLoad;
#pragma mark - Image Transition
@property (nonatomic, strong, nullable) SDWebImageTransition *sd_imageTransition;
#if SD_UIKIT
#pragma mark - Activity indicator
- (void)sd_setShowActivityIndicatorView:(BOOL)show;
- (void)sd_setIndicatorStyle:(UIActivityIndicatorViewStyle)style;
- (BOOL)sd_showActivityIndicatorView;
- (void)sd_addActivityIndicator;
- (void)sd_removeActivityIndicator;
#endif
@end
#endif
