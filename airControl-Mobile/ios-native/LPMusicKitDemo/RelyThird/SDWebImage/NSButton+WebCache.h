#import "SDWebImageCompat.h"
#if SD_MAC
#import "SDWebImageManager.h"
@interface NSButton (WebCache)
#pragma mark - Image
- (nullable NSURL *)sd_currentImageURL;
- (void)sd_setImageWithURL:(nullable NSURL *)url NS_REFINED_FOR_SWIFT;
- (void)sd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder NS_REFINED_FOR_SWIFT;
- (void)sd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(SDWebImageOptions)options NS_REFINED_FOR_SWIFT;
- (void)sd_setImageWithURL:(nullable NSURL *)url
                 completed:(nullable SDExternalCompletionBlock)completedBlock;
- (void)sd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                 completed:(nullable SDExternalCompletionBlock)completedBlock NS_REFINED_FOR_SWIFT;
- (void)sd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(SDWebImageOptions)options
                 completed:(nullable SDExternalCompletionBlock)completedBlock;
- (void)sd_setImageWithURL:(nullable NSURL *)url
          placeholderImage:(nullable UIImage *)placeholder
                   options:(SDWebImageOptions)options
                  progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                 completed:(nullable SDExternalCompletionBlock)completedBlock;
#pragma mark - Alternate Image
- (nullable NSURL *)sd_currentAlternateImageURL;
- (void)sd_setAlternateImageWithURL:(nullable NSURL *)url NS_REFINED_FOR_SWIFT;
- (void)sd_setAlternateImageWithURL:(nullable NSURL *)url
                   placeholderImage:(nullable UIImage *)placeholder NS_REFINED_FOR_SWIFT;
- (void)sd_setAlternateImageWithURL:(nullable NSURL *)url
                   placeholderImage:(nullable UIImage *)placeholder
                            options:(SDWebImageOptions)options NS_REFINED_FOR_SWIFT;
- (void)sd_setAlternateImageWithURL:(nullable NSURL *)url
                          completed:(nullable SDExternalCompletionBlock)completedBlock;
- (void)sd_setAlternateImageWithURL:(nullable NSURL *)url
                   placeholderImage:(nullable UIImage *)placeholder
                          completed:(nullable SDExternalCompletionBlock)completedBlock NS_REFINED_FOR_SWIFT;
- (void)sd_setAlternateImageWithURL:(nullable NSURL *)url
                   placeholderImage:(nullable UIImage *)placeholder
                            options:(SDWebImageOptions)options
                          completed:(nullable SDExternalCompletionBlock)completedBlock;
- (void)sd_setAlternateImageWithURL:(nullable NSURL *)url
                   placeholderImage:(nullable UIImage *)placeholder
                            options:(SDWebImageOptions)options
                           progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                          completed:(nullable SDExternalCompletionBlock)completedBlock;
#pragma mark - Cancel
- (void)sd_cancelCurrentImageLoad;
- (void)sd_cancelCurrentAlternateImageLoad;
@end
#endif
