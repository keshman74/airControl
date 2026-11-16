//
//  LPDevice.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPDeviceStatus.h"
#import "LPMediaInfo.h"

@class LPPassthrough;
@class LPDeviceInfo;
@class LPDeviceTimer;
@class LPDevicePreset;
@class LPDeiceAlarm;
@class LPDevicePlayer;
@class LPDeviceOTA;
@class LPDeviceSettings;
@class LPDeviceSpotifySettings;

NS_ASSUME_NONNULL_BEGIN

typedef void (^DeviceUpdateBlock)(BOOL success);
/// Block returned by interacting with the device
typedef void (^LPSDKReturnBlock)(NSURLResponse * _Nullable response, id _Nullable responseObject,  NSError * _Nullable error);
/// Device objects, including device information and various functional operations of the device
@interface LPDevice : NSObject
/// Device information, including the basic information of the device, such as IP, Name and other attributes
@property (nonatomic, strong)LPDeviceStatus *deviceStatus;
/// Device media information
@property (nonatomic, strong)LPMediaInfo *mediaInfo;
/// Get device settings object
- (LPDeviceSettings *)deviceSettings;
/// Get pass through object
- (LPPassthrough *)getPassthrough;
/// Get timer object
- (LPDeviceTimer *)getTimer;
/// Get Preset object
- (LPDevicePreset *)getPreset;
/// Get alarm object
- (LPDeiceAlarm *)getAlarm;
/// Get Device's player.
- (LPDevicePlayer *)getPlayer;
/// Get OTA object
- (LPDeviceOTA *)getOTA;
/// Get device Spotify settings object
- (LPDeviceSpotifySettings *)spotifySettings;

/// Device status
@property (nonatomic, strong) LPDeviceInfo * _Nullable deviceInfo;

#ifndef LINKPLAY_PUBLIC_HEADER
-(void)updateDeviceInfo:(DeviceUpdateBlock)block;
- (void)reconfirmLPDevice;
#endif

@end

NS_ASSUME_NONNULL_END
