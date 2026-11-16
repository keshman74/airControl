//
//  LPDeviceManager.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPDevice.h"

NS_ASSUME_NONNULL_BEGIN
/// Object to deal with the device online/offline event.
@protocol LPDeviceManagerObserver <NSObject>

@optional
/// Device online notification
/// @param device device
- (void)onLPDeviceOnline:(LPDevice *)device;
/// Device offline notification
/// @param device device
- (void)onLPDeviceOffline:(LPDevice *)device;
/// Device update notification
/// @param device device
- (void)onLPDeviceUpdate:(LPDevice *)device;

@end


@interface LPDeviceManager : NSObject

+ (LPDeviceManager *)sharedInstance;
/// Device List
@property (nonatomic, strong) NSMutableArray <LPDevice *> *deviceArray;

@property (nonatomic, strong) NSRecursiveLock * deviceArrayLock;

@property (nonatomic, assign) BOOL needBackgroundMode;
/// SDK Version
@property (nonatomic, readonly) NSString *version;

/// Switch on/off for the SDK log.
/// @param logOn BOOL
- (void)debugSwitch:(BOOL)logOn;

/// When the device is abnormally powered off or shut down, the duration of the App detecting whether the device has been offline, the default is 60s
/// @param time Check time, default is 60s
- (void)checkDeviceOfflineTime:(int)time;
/// Start discover devices.
/// @param searchKey Default use empty string, if you want to distinguish your device from others, then this key should be the same with the firmware definition.
- (void)start:(NSString *)searchKey;
/// Add observer to receive the callback.
/// @param observer observer
- (void)addObserver:(id<LPDeviceManagerObserver>)observer;
/// Remove the observer.
/// @param observer observer
- (void)removeObserver:(id<LPDeviceManagerObserver>)observer;
/// Stop discovering.
- (void)stop;
/// Get all master devices, which is the master of the multi-room to play music synchronized.
- (NSArray<LPDevice *> *)getMasterDevices;
/// Get device object with UUID.
/// @param UUID Device UUID
- (LPDevice *)deviceForID:(NSString *)UUID;
/// Get device object with IP.
/// @param IP Device IP
- (LPDevice *)deviceForIP:(NSString *)IP;
/// Get device object with MAC.
/// @param MAC Device MAC
- (LPDevice *)deviceForMAC:(NSString *)MAC;
/// Delete cached device with UUID. If the device is actually discoverable, then SDK would discover it again
/// @param UUID Device UUID
- (void)removeDevice:(NSString *)UUID;
/// Get master device's slave device list.
/// @param UUID Device UUID
-(NSArray<LPDevice *> *)slaveDeviceArray:(NSString *)UUID;
/// Get slave device's master device.
/// @param device Slave device
-(LPDevice *)getMasterDeviceWithSlaveDevice:(LPDevice *)device;

- (void)upnpDeviceStop;
- (void)upnpDeviceStart;


@end

NS_ASSUME_NONNULL_END
