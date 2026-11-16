#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
#import "SDWebImageOperation.h"
typedef NS_OPTIONS(NSUInteger, SDWebImageDownloaderOptions) {
    SDWebImageDownloaderLowPriority = 1 << 0,
    SDWebImageDownloaderProgressiveDownload = 1 << 1,
    SDWebImageDownloaderUseNSURLCache = 1 << 2,
    SDWebImageDownloaderIgnoreCachedResponse = 1 << 3,
    SDWebImageDownloaderContinueInBackground = 1 << 4,
    SDWebImageDownloaderHandleCookies = 1 << 5,
    SDWebImageDownloaderAllowInvalidSSLCertificates = 1 << 6,
    SDWebImageDownloaderHighPriority = 1 << 7,
    SDWebImageDownloaderScaleDownLargeImages = 1 << 8,
};
typedef NS_ENUM(NSInteger, SDWebImageDownloaderExecutionOrder) {
    SDWebImageDownloaderFIFOExecutionOrder,
    SDWebImageDownloaderLIFOExecutionOrder
};
FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageDownloadStartNotification;
FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageDownloadStopNotification;
typedef void(^SDWebImageDownloaderProgressBlock)(NSInteger receivedSize, NSInteger expectedSize, NSURL * _Nullable targetURL);
typedef void(^SDWebImageDownloaderCompletedBlock)(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, BOOL finished);
typedef NSDictionary<NSString *, NSString *> SDHTTPHeadersDictionary;
typedef NSMutableDictionary<NSString *, NSString *> SDHTTPHeadersMutableDictionary;
typedef SDHTTPHeadersDictionary * _Nullable (^SDWebImageDownloaderHeadersFilterBlock)(NSURL * _Nullable url, SDHTTPHeadersDictionary * _Nullable headers);
@interface SDWebImageDownloadToken : NSObject <SDWebImageOperation>
@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, strong, nullable) id downloadOperationCancelToken;
@end
@interface SDWebImageDownloader : NSObject
@property (assign, nonatomic) BOOL shouldDecompressImages;
@property (assign, nonatomic) NSInteger maxConcurrentDownloads;
@property (readonly, nonatomic) NSUInteger currentDownloadCount;
@property (assign, nonatomic) NSTimeInterval downloadTimeout;
@property (readonly, nonatomic, nonnull) NSURLSessionConfiguration *sessionConfiguration;
@property (assign, nonatomic) SDWebImageDownloaderExecutionOrder executionOrder;
+ (nonnull instancetype)sharedDownloader;
@property (strong, nonatomic, nullable) NSURLCredential *urlCredential;
@property (strong, nonatomic, nullable) NSString *username;
@property (strong, nonatomic, nullable) NSString *password;
@property (nonatomic, copy, nullable) SDWebImageDownloaderHeadersFilterBlock headersFilter;
- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration NS_DESIGNATED_INITIALIZER;
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field;
- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field;
- (void)setOperationClass:(nullable Class)operationClass;
- (nullable SDWebImageDownloadToken *)downloadImageWithURL:(nullable NSURL *)url
                                                   options:(SDWebImageDownloaderOptions)options
                                                  progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                                                 completed:(nullable SDWebImageDownloaderCompletedBlock)completedBlock;
- (void)cancel:(nullable SDWebImageDownloadToken *)token;
- (void)setSuspended:(BOOL)suspended;
- (void)cancelAllDownloads;
- (void)createNewSessionWithConfiguration:(nonnull NSURLSessionConfiguration *)sessionConfiguration;
- (void)invalidateSessionAndCancel:(BOOL)cancelPendingOperations;
@end
