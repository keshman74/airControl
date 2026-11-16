#import "SDWebImageCompat.h"
#if SD_UIKIT || SD_MAC
#import "SDImageCache.h"
#if SD_UIKIT
typedef UIViewAnimationOptions SDWebImageAnimationOptions;
#else
typedef NS_OPTIONS(NSUInteger, SDWebImageAnimationOptions) {
    SDWebImageAnimationOptionAllowsImplicitAnimation = 1 << 0, 
};
#endif
typedef void (^SDWebImageTransitionPreparesBlock)(__kindof UIView * _Nonnull view, UIImage * _Nullable image, NSData * _Nullable imageData, SDImageCacheType cacheType, NSURL * _Nullable imageURL);
typedef void (^SDWebImageTransitionAnimationsBlock)(__kindof UIView * _Nonnull view, UIImage * _Nullable image);
typedef void (^SDWebImageTransitionCompletionBlock)(BOOL finished);
@interface SDWebImageTransition : NSObject
@property (nonatomic, assign) BOOL avoidAutoSetImage;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong, nullable) CAMediaTimingFunction *timingFunction NS_AVAILABLE_MAC(10_7);
@property (nonatomic, assign) SDWebImageAnimationOptions animationOptions;
@property (nonatomic, copy, nullable) SDWebImageTransitionPreparesBlock prepares;
@property (nonatomic, copy, nullable) SDWebImageTransitionAnimationsBlock animations;
@property (nonatomic, copy, nullable) SDWebImageTransitionCompletionBlock completion;
@end
@interface SDWebImageTransition (Conveniences)
#if __has_feature(objc_class_property)
@property (nonatomic, class, nonnull, readonly) SDWebImageTransition *fadeTransition;
@property (nonatomic, class, nonnull, readonly) SDWebImageTransition *flipFromLeftTransition;
@property (nonatomic, class, nonnull, readonly) SDWebImageTransition *flipFromRightTransition;
@property (nonatomic, class, nonnull, readonly) SDWebImageTransition *flipFromTopTransition;
@property (nonatomic, class, nonnull, readonly) SDWebImageTransition *flipFromBottomTransition;
@property (nonatomic, class, nonnull, readonly) SDWebImageTransition *curlUpTransition;
@property (nonatomic, class, nonnull, readonly) SDWebImageTransition *curlDownTransition;
#else
+ (nonnull instancetype)fadeTransition;
+ (nonnull instancetype)flipFromLeftTransition;
+ (nonnull instancetype)flipFromRightTransition;
+ (nonnull instancetype)flipFromTopTransition;
+ (nonnull instancetype)flipFromBottomTransition;
+ (nonnull instancetype)curlUpTransition;
+ (nonnull instancetype)curlDownTransition;
#endif
@end
#endif
