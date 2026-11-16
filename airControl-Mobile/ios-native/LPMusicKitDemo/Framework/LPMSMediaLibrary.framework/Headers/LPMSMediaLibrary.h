//
//  LPMSMediaLibrary.h
//  LPMSMediaLibrary
//
//  Created by sunyu on 2019/7/23.
//  Copyright © 2019 Linkplay. All rights reserved.
//

/**
iOS 9 and later
Xcode 11 and later

依赖库说明：
1.AVFoundation 和 和Mediaplayer: 用于播放音乐
2.TSLibraryImport: 用于copy本地音乐
3.HTTPConnection+iTunes: 用于解析对应的本地音乐
4.SDWebImage 用于加载图片
5.LPMDPKit 用于整合播放信息
 
需要导入文件:
MMPSilence 无声音乐

info.plist权限：
1. 本地音乐权限：NSAppleMusicUsageDescription
2. App 后台权限
 
注意，播放音乐，为了App长后台，需要在后台播放无声音乐，所以如果有通过蓝牙控制播放音乐，会受到影响

使用文档：
https://confluence.linkplay.com/pages/viewpage.action?pageId=44501545

*/


#import <UIKit/UIKit.h>

#import <LPMSMediaLibrary/LPMSMediaLibrary.h>
#import <LPMSMediaLibrary/LPMSLibraryPlayItem.h>
#import <LPMSMediaLibrary/LPMSLibraryManager.h>


//! Project version number for LPAlexaKit.
FOUNDATION_EXPORT double LPAlexaKitVersionNumber;

//! Project version string for LPAlexaKit.
FOUNDATION_EXPORT const unsigned char LPAlexaKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <LPAlexaKit/PublicHeader.h>


