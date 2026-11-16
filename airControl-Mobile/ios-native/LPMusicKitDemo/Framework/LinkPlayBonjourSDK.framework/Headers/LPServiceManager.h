//
//  LPServiceManager.h
//  BonjourSDK
//
//  Created by sunyu on 2018/11/12.
//  Copyright © 2018年 sunyu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPDeviceProtocol.h"

@protocol LPService <NSObject>

@optional

/// Device online method
/// @param device Device
- (void)LPServiceAdd:(id<LPDeviceProtocol>)device;
/// Device update method
/// @param device Device
- (void)LPServiceUpdate:(id<LPDeviceProtocol>)device;
/// Device offline method
/// @param device Device
- (void)LPServiceRemove:(id<LPDeviceProtocol>)device;
/// Device background to foreground detection available
/// @param device Device
- (void)LPServiceReady:(id<LPDeviceProtocol>)device;

@end

@interface LPServiceManager : NSObject

+ (LPServiceManager *)sharedInstance;

@property (weak, nonatomic) id<LPService>delegate;
// Background Modes
@property (assign) BOOL needBackgroundMode;

/// Start searching for devices
/// @param dict @{@"serviceType": @"_linkplay._tcp", @"serviceDomain":@"local."}
- (void)start:(NSDictionary *)dict;
/// reStart searching for devices
/// @param dict @{@"serviceType": @"_linkplay._tcp", @"serviceDomain":@"local."}
- (void)reStartLPBonjourDiscovery:(NSDictionary *)dict;
/// Confirm if the device is online
/// @param uuid UUID
/// @param needCallback callback
- (void)reconfirmRecord:(NSString *)uuid needCallback:(BOOL)needCallback;
/// Resolve service
/// @param uuid UUID
- (void)resolveService:(NSString *)uuid;
/// Whether to open debug log
/// @param logOn logOn
- (void)setDebugLogOn:(BOOL)logOn;

/// Just delete the service, don't affect the online devices and temporary testing.
/// @param uuid UUID
- (void)deleteService:(NSString *)uuid;

@end
