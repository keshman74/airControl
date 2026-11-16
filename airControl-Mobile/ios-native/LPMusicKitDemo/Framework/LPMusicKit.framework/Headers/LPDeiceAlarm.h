//
//  LPDeiceAlarm.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

typedef void (^LPGetAlarmBlock)(NSString * _Nullable alarmString);

typedef void (^LPAlarmBlock)(BOOL isSuccess);

/// Device alarm
@interface LPDeiceAlarm : NSObject

- (LPDeiceAlarm *)initWithUUID:(NSString *)uuid;
/// Get alarm list in the device
/// @param completionHandler Callback
- (void)getAlarms:(LPGetAlarmBlock _Nullable)completionHandler;
/// Add new alarm
/// @param infomation Alarm infomation
/// @param completionHandler Callback
- (void)addAlarmWithInfomation:(NSDictionary *)infomation completionHandler:(LPAlarmBlock _Nullable)completionHandler;
/// Edit alarm.
/// @param infomation Alarm infomation
/// @param completionHandler Callback
- (void)editAlarmWithInfomation:(NSDictionary *)infomation completionHandler:(LPAlarmBlock _Nullable)completionHandler;
/// Delete alarm
/// @param name Alarm name
/// @param completionHandler Callback
- (void)deleteAlarmWithName:(NSString *)name completionHandler:(LPAlarmBlock _Nullable)completionHandler;
/// Enable/disable alarm
/// @param infomation Alarm infomation
/// @param completionHandler Callback
- (void)setAlarmSwitchOnWithInfomation:(NSDictionary *)infomation completionHandler:(LPAlarmBlock _Nullable)completionHandler;

- (int)getAlarmMaxNum;


@end

NS_ASSUME_NONNULL_END
