//
//  LPWiFiSetupManager.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/19.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <LPMusicKit/LPDevice.h>

NS_ASSUME_NONNULL_BEGIN


@interface LPApItem : NSObject

@property (nonatomic, copy) NSString *ssid;
@property (nonatomic, copy) NSString *rssi;
@property (nonatomic, copy) NSString *mac;
@property (nonatomic, copy) NSString *channel;
@property (nonatomic, copy) NSString *auth;
@property (nonatomic, copy) NSString *encry;
@property (nonatomic, copy) NSString *extch;

@end

typedef void (^LPApListBlock)(NSMutableArray <LPApItem *> * LPApList);

typedef void (^LPWiFiSetupSuccess)(LPDevice *device);

typedef void (^LPWiFiSetupFailed)(int errorCode);

/// Wi-Fi Setup
@interface LPWiFiSetupManager : NSObject


+ (LPWiFiSetupManager *)sharedInstance;

/// Whether to connect to the device hotspot
/// @param time Whether to connect to the detection time of the device hotspot
/// @param block Callback
- (void)isLinkplayHotspotWithCheckTime:(int)time block:(void(^)(BOOL isDirect))block;

/// Get a list of routes near the device
/// @param block Callback
- (void)getApList:(LPApListBlock)block;

/// Send network configuration command
/// @param apItem Selected apItem
/// @param pass Wi-Fi password
/// @param success Successful callback
/// @param failed Failed callback
- (void)connectToWiFi:(LPApItem *)apItem pass:(NSString *)pass success:(LPWiFiSetupSuccess)success failed:(LPWiFiSetupFailed)failed;
/// After the network distribution fails, if the WiFi connected to the mobile phone and the selected target router Wi-Fi are inconsistent, you can call this method to re-detect the network distribution.
/// @param time Re-detection time, default 30s
/// @param success Successful callback
/// @param failed Failed callback
- (void)retryCheckWithTime:(int)time success:(LPWiFiSetupSuccess)success failed:(LPWiFiSetupFailed)failed;

@end

NS_ASSUME_NONNULL_END
