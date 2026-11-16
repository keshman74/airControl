//
//  LPPeripheral.h
//  iMuzo
//
//  Created by sunyu on 2019/12/18.
//  Copyright © 2019 wiimu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "LPBLEEnum.h"

NS_ASSUME_NONNULL_BEGIN

@interface LPPeripheral : NSObject

@property (nonatomic, strong) CBPeripheral *peripheral;

/// MAC address
@property (nonatomic, strong) NSData *MACData;

/// BLE alias, if the device supports Bluetooth name modification
@property (nonatomic, copy) NSString *kCBAdvDataLocalName;

/// BLE protocol type used by the device
@property (nonatomic, assign) LPBLEProtocolType BLEProtocolType;

/// Used with BLEProtocolType to determine the encryption method in BLE transmission.
@property (nonatomic, assign) LPBLEProtocolVersion BLEProtocolVersion;

/// BLE device Id identification
@property (nonatomic, copy) NSString *BLEDeviceId;

/// Device uuid
@property (nonatomic, copy) NSString *UUID;

/// Determine whether the device supports 5G BLE Setup
@property (nonatomic, assign) BOOL isSupport5G;

@end

NS_ASSUME_NONNULL_END
