//
//  LPMediaSourceProtocol.h
//  LPMDPKit
//
//  Created by 程龙 on 2020/2/20.
//  Copyright © 2020 Linkplay-jack. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum{
    LPStringType,
    LPJsonType,
    LPXmlType,
    LPImageType,
} LPResponseType;

@protocol LPMediaSourceProtocol <NSObject>

@optional

//IP
- (NSString *)LPIpAddressWithDeviceId:(NSString *)deviceId;

//Get UserInfo
- (void)LPGetUserInfoWithDeviceId:(NSString *)deviceId source:(NSString *)source block:(void(^)(int ret, NSString *_Nullable result))block;

//Log Out
- (void)LPLogOutWithDeviceId:(NSString *)deviceId source:(NSString *)source block:(void(^)(int ret, NSError *_Nullable error))block;

//HTTP
- (NSURLSessionDataTask *)LPCommonHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError * _Nullable error))failure timeout:(NSTimeInterval)time;

//Source Http
- (NSURLSessionDataTask *)LPCommonSourceHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError *_Nullable error))failure redirect:(void (^)(NSURLSessionTask *operation, NSHTTPURLResponse *_Nullable responseObject))redirect timeout:(NSTimeInterval)time;

- (void)LPGetNextToPlayInfoWithDeviceId:(NSString *)deviceId block:(void(^)(int ret, NSDictionary *dictionary))block;

///Login
- (void)LPLoginBoxWithSource:(NSString *)source deviceId:(NSString *)deviceId username:(NSString *)username password:(NSString *)password block:(void(^)(int ret,NSString* Result))block;


///Favorite
- (void)LPFavoriteWithSource:(NSString *)source deviceId:(NSString *)deviceId action:(NSString *)action mediaType:(NSString *)mediaType mediaID:(NSString *)mediaID block:(void(^)(int ret,NSString* Result))block;

- (void)LPGetUserInfoWithDeviceId:(NSString *)deviceId source:(NSString *)source refreshToken:(NSString *)refresh block:(void(^)(int ret, NSString *_Nullable result))block;

///Play
- (void)LPPlayCurrentQueueWithIndex:(int)index deviceId:(NSString *)deviceId block:(void(^)(int ret,NSString* Result))block;


@end

NS_ASSUME_NONNULL_END
