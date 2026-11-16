//
//  LPDeviceTimer.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPDeviceTimer : NSObject

- (LPDeviceTimer *)initWithUUID:(NSString *)uuid;
/// Get timer
/// @param time The time of automatic shutdown, the unit is s
/// @param completionHandler Callback
- (void)setTimerWithTime:(NSInteger)time completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;
/// Get the currently set timer
/// @param completionHandler Callback
- (void)getTimer:(LPSDKReturnBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
