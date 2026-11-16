//
//  LPMusicKit.h
//  LPMusicKit
//
//  Created by sunyu on 2019/7/12.
//  Copyright © 2019 Linkplay. All rights reserved.
//
/**
iOS 9 and later
Xcode 11 and later

依赖库说明：
1.LinkPlayBonjourSDK: 用于设备发现
2.AFNetworking: 用于网络请求
3.KissXML: 用于XML解析
4.CocoaHTTP 用于和MCU交互

Build Settings设置:
Other Linker Flags: -ObjC
Header Search Paths: /usr/include/libxml2
Enable Bitcode: NO

使用文档：
https://confluence.linkplay.com/pages/viewpage.action?pageId=44501545

*/




#import <UIKit/UIKit.h>
#import <LPMusicKit/LPDeviceManager.h>
#import <LPMusicKit/LPDevice.h>
#import <LPMusicKit/LPMultiroomManager.h>
#import <LPMusicKit/LPDeviceSettings.h>
#import <LPMusicKit/LPDevicePlayer.h>
#import <LPMusicKit/LPMediaInfo.h>
#import <LPMusicKit/LPDevicePreset.h>
#import <LPMusicKit/LPDeviceStatus.h>
#import <LPMusicKit/LPDeiceAlarm.h>
#import <LPMusicKit/LPDeviceTimer.h>
#import <LPMusicKit/LPPassthrough.h>
#import <LPMusicKit/LPDeviceOTA.h>
#import <LPMusicKit/LPMediaServer.h>
#import <LPMusicKit/LPWiFiSetupManager.h>
#import <LPMusicKit/LPAlexaObject.h>
#import <LPMusicKit/LPDeviceInfo.h>
#import <LPMusicKit/LPNetwork.h>
#import <LPMusicKit/LPUSBManager.h>
#import <LPMusicKit/LPMediaSourceAction.h>
#import <LPMusicKit/LPDeviceSpotifySettings.h>



//! Project version number for LPMusicKit.
FOUNDATION_EXPORT double LPMusicKitVersionNumber;

//! Project version string for LPMusicKit.
FOUNDATION_EXPORT const unsigned char LPMusicKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <LPMusicKit/PublicHeader.h>


