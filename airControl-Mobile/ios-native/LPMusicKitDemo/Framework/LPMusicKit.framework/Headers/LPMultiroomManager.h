//
//  LPMultiroomManager.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^LPMultiroomBlock)(BOOL isSuccess);

NS_ASSUME_NONNULL_BEGIN

/// Multi-Room Music
@interface LPMultiroomManager : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, readonly) NSString *version;

/// Multiple devices form a room to achieve the purpose of playing music simultaneously,
/// @param deviceList Need multi-room device list
/// @param handler Callback
- (void)deviceMultiroomWithDeviceList:(NSArray<LPDevice *> * _Nonnull)deviceList handler:(LPMultiroomBlock)handler;

/*
 * masterDevice "Master device", slaveDeviceList is a list of "child devices" in the room.
 * If the incoming masterDevice is nil, the devices in the slaveDeviceList will be deleted from the room, and the music of the masterDevice will no longer be played synchronously.
 * If the incoming masterDevice is not nil, the devices in the slaveDeviceList will form a room with the masterDevice and play music in synchronization
 */
/// @param slaveDeviceList SlaveDevice list
/// @param masterDevice Master device, maybe empty
/// @param handler Callback
- (void)deviceMultiroomWithSlaveDeviceList:(NSArray<LPDevice *> * _Nonnull)slaveDeviceList masterDevice:(LPDevice * _Nullable)masterDevice handler:(LPMultiroomBlock)handler;

@end

NS_ASSUME_NONNULL_END

