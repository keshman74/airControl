//
//  LPDeviceOTA.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define MV_UP_STATUS_UNKNOWN          0
#define MV_UP_STATUS_DOWNLOAD_START   1
#define MV_UP_STATUS_DOWNLOAD_FAILED  2
#define MV_UP_STATUS_WRITE_START      3
#define MV_UP_STATUS_WRITE_FINISH     4
#define MV_UP_STATUS_WRITE_FAILED     5
#define MV_UP_STATUS_COMPLETE         6
#define MV_UP_STATUS_NOT_IN_OTA       8


@interface LPOTATimeoutObj : NSObject


/// firmware download time, default 120s
@property (nonatomic) int FWDownloadTimeout;
/// firmware write(update) time, default 120s
@property (nonatomic) int FWWriteTimeout;
/// firmware reboot time, default 120s
@property (nonatomic) int FWRebootTimeout;
/// MCU download time, default 120s
@property (nonatomic) int MCUDownloadTimeout;
/// MCU write(update) time, default 120s
@property (nonatomic) int MCUWriteTimeout;
/// MCU reboot time, default 120s
@property (nonatomic) int MCURebootTimeout;
/// DSP download time, default 120s
@property (nonatomic) int DSPDownloadTimeout;
/// DSP write(update) time, default 120s
@property (nonatomic) int DSPWriteTimeout;
/// DSP reboot time, default 120s
@property (nonatomic) int DSPRebootTimeout;

@end

/// OTA progress of the object
@interface LPOTAPercentObj : NSObject

/// download progress percent
@property (nonatomic) float downloadPercent;
/// upgrade progress percent
@property (nonatomic) float upgradePercent;
/// reboot progress percent
@property (nonatomic) float recatoryPercent;
/// OTA Status
@property (nonatomic) int firmwareOTAStatus;
/// OTA expect time
@property (nonatomic) int expectTime;
/// total Percent
@property (nonatomic) float totalPercent;

@end

/// OTA UI and remaining time delegate
@protocol LPOTAPercentObjDelegate <NSObject>
/// OTA progress
- (void)LPOTAPercentUpdate:(LPOTAPercentObj *)percentObj;

@end

/// OTA Class
@interface LPDeviceOTA : NSObject

- (LPDeviceOTA *)initWithUUID:(NSString *)uuid;

@property (nonatomic, readonly) NSString *version;
/** The results block, there are two cases when the upgrade fails:
* One is that the device fails to return.
* Two is that the upgrade has timed out, which caused the failure.
The two cases correspond to different prompts. */
typedef void(^LPFirmwareUpdateResultBlock)(BOOL isSuccess, BOOL isTimeout);
/// Forces the end of the App's OTA internal loop, but the firmware does not end
@property (nonatomic) BOOL stopAppOTA;
/// OTA UI and remaining time delegate
@property(nonatomic, weak) id <LPOTAPercentObjDelegate> delegate;


/// Detect if there is an OTA upgrade
- (BOOL)checkUpdate;

/// Start firmware OTA
/// @param timeoutObj OTA time object
/// @param completionHandler reuslt block
- (void)firmwareStartUpdate:(LPOTATimeoutObj *)timeoutObj completionHandler:(LPFirmwareUpdateResultBlock)completionHandler;



@end

NS_ASSUME_NONNULL_END
