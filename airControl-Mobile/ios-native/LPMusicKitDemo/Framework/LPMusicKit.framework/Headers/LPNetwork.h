//
//  LPNetwork.h
//  LPMusicKit
//
//  Created by sunyu on 2020/2/20.
//  Copyright © 2020 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPMediaSourceProtocol.h"

NS_ASSUME_NONNULL_BEGIN
//@class LPDeviceStatus;
@interface LPNetwork : NSObject

#pragma mark - 网络请求
// Get
+(NSURLSessionDataTask *)commonHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError * _Nullable error))failure;

+(NSURLSessionDataTask *)commonHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError * _Nullable error))failure timeout:(NSTimeInterval)time;

+(NSURLSessionDataTask *)commonHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError * _Nullable error))failure redirect:(void (^)(NSURLSessionTask *operation, NSHTTPURLResponse *_Nullable responseObject))redirect timeout:(NSTimeInterval)time;

+(NSURLSessionDataTask *)commonHTTPMethod:(NSString *)url responseType:(LPResponseType)type securityType:(LPSecurityType)securityType success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError *_Nullable error))failure redirect:(void (^)(NSURLSessionTask *operation, NSHTTPURLResponse * _Nullable responseObject))redirect timeout:(NSTimeInterval)time;

//TuneIn source
+(NSURLSessionDataTask *)commonSourceHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError *_Nullable error))failure redirect:(void (^)(NSURLSessionTask *operation, NSHTTPURLResponse *_Nullable responseObject))redirect timeout:(NSTimeInterval)time;

//Post
+(NSURLSessionDataTask *)commonPostMethod:(NSString *)url responseType:(LPResponseType)type body:(NSDictionary *_Nullable)body success:(void (^)(NSURLSessionDataTask *operation, NSDictionary *_Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError *_Nullable error))failure redirect:(void (^)(NSURLSessionTask *operation, NSHTTPURLResponse *_Nullable responseObject))redirect timeout:(NSTimeInterval)time;

+(NSURLSessionDataTask *)PostHTTPMethod:(NSString *)url withParameters:(id _Nullable)parameters httpHeader:(NSDictionary *)headerValue success:(void (^)(NSURLSessionDataTask *operation, NSDictionary * _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError *_Nullable error))failure;

+(NSURLSessionDataTask *)POST:(NSString *)url parameters:(id)parameters isNeedSerializer:(BOOL)isNeedSerializer success:(void (^)(NSURLSessionDataTask *operation, NSDictionary *_Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError *_Nullable error))failure;

//带Header的请求
+(NSURLSessionDataTask *)commonHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError *_Nullable error))failure headers:(NSDictionary *)headers;
+(NSURLSessionDataTask *)commonHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError *_Nullable error))failure timeout:(NSTimeInterval)time headers:(NSDictionary *)headers;
+(NSURLSessionDataTask *)commonHTTPMethod:(NSString *)url responseType:(LPResponseType)type success:(void (^)(NSURLSessionDataTask *operation, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask *operation, NSError * _Nullable error))failure redirect:(void (^)(NSURLSessionTask *operation, NSHTTPURLResponse * _Nullable responseObject))redirect timeout:(NSTimeInterval)time headers:(NSDictionary *)headers;

@end

NS_ASSUME_NONNULL_END
