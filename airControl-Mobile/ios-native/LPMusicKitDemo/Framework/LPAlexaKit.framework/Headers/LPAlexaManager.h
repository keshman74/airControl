//
//  LPAlexaManager.h
//  LPAlexaKit
//
//  Created by sunyu on 2019/7/29.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <LPMusicKit/LPDevice.h>

// Alexa Language
#define LANGUAGE_EN_US @"en-US"
#define LANGUAGE_EN_GB @"en-GB"
#define LANGUAGE_DE_DE @"de-DE"
#define LANGUAGE_EN_CA @"en-CA"
#define LANGUAGE_JA_JP @"ja-JP"
#define LANGUAGE_EN_IN @"en-IN"
#define LANGUAGE_EN_AUT @"en-AU"
#define LANGUAGE_FR_FR @"fr-FR"

NS_ASSUME_NONNULL_BEGIN

@protocol LPLPAlexaLoginDelegate <NSObject>

- (void)bleConnectionInterrupt;

@end

@interface LPAlexaManager : NSObject

+ (LPAlexaManager *)sharedInstance;

@property (nonatomic, readonly) NSString *version;
- (void)setAuthcodeWithDeivce:(LPDevice *)device completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;
/// Alexa 登出设备
/// @param device 设备对象
/// @param completionHandler 结果
- (void)logoutWithDevice:(LPDevice *)device completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;
/// 获取Alexa当前状态
/// @param device 设备对象
/// @param completionHandler 结果
- (void)getAlexaStatus:(LPDevice *)device completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

/// 设置Alexa 语言
/// @param device 设备对象
/// @param language Alexa 语言
/// @param completionHandler 结果
- (void)setLanguage:(LPDevice *)device selectLanguage:(NSString *)language completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;
/// 获取Alexa当前语言
/// @param device 设备对象
/// @param completionHandler 结果
- (void)getLanguage:(LPDevice *)device completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

/// 获取设备 询问Alexa 是否有咚的提示音
/// @param device 设备对象
/// @param completionHandler 结果
- (void)getPromptStatus:(LPDevice *)device completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

/// 设置设备 询问Alexa 是否有咚的提示音
/// @param device 设备对象
/// @param status status
/// @param completionHandler 结果
- (void)setPromptStatus:(LPDevice *)device status:(BOOL)status completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
