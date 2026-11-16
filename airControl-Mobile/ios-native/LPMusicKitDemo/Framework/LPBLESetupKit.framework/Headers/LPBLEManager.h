//
//  LPBLELinkManager.h
//  BLELinkManager
//
//  Created by Aric on 2019/8/28.
//  Copyright © 2019年 Aric. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "LPBLEEnum.h"

@class CBPeripheral;
@class LPPeripheral;
@class LPBLEManager;

NS_ASSUME_NONNULL_BEGIN

@protocol LPBLEManagerDelegate <NSObject>

@optional

/// Bluetooth is not open
/// @param BLEManger LPBLEManager object
/// @param isPoweredOff Status (YES represents Bluetooth is not open)
- (void)BLEManger:(LPBLEManager *)BLEManger BLEPoweredOff:(BOOL)isPoweredOff;

/// Bluetooth state
/// @param BLEManger LPBLEManager object
/// @param state Bluetooth state
- (void)BLEManger:(LPBLEManager *)BLEManger BLEState:(CBCentralManagerState)state;

/**
 * BLE connection interrupted.
 * When the BLE network configuration is completed, the device will actively disconnect the BLE connection with the mobile phone, please ignore the BLE disconnect proxy method triggered this time
 */
- (void)BLEMangerDidDisconnectPeripheral;

@end

@interface LPBLEManager : NSObject

+ (instancetype)shareInstance;

@property (nonatomic, readonly) NSString *version;

@property (nonatomic, weak) id<LPBLEManagerDelegate> delegate;

/// Whether Bluetooth is on
@property (nonatomic, assign, readonly) BOOL isBLEEnable;

@property (nonatomic, assign, readonly) CBCentralManagerState state;

@property (nonatomic, strong, readonly) LPPeripheral *peripheral;

/// BLE connected device timeout, default is 30s
@property (nonatomic, assign) int connectTimeout;

/**
 Scan BLE device

 @param callback Search BLE device list callback.
 */
- (void)startScan:(void (^)(LPPeripheral *peripheral))callback;

/**
 Stop scan.
 */
- (void)stopScan;

/**
 Connect BLE device
 
 @param peripheral The peripheral you want
 @param callback Connect result callback.
 */
- (void)connectBLE:(LPPeripheral *)peripheral callback:(void (^)(LP_BLE_CONNECT_RESULT state))callback;

/**
 Disconnect BLE.
 */
- (void)disconnectBLE;

/**
 Get device wifi list
 @warning
 Only BLE new protocol can get WiFi list around the device.
 The data structure is as follows:
 
 { "auth":"WPA2PSK",
 "bssid":"4c:01:43:10:db:f3",
 "channel":1,
 "encry":"AES",
 "extch":0,
 "rssi":100,
 "ssid" :"4C696E6B706C61792D6565726F"
 }
 
 @param callback callback.
 */
- (void)getWLANListWithCallback:(void(^)(id _Nullable apList))callback;

- (void)connectWLAN:(NSString *)ssid
           password:(NSString *)password
           callback:(void(^)(LP_CONNECT_AP_STATE code, id _Nullable responseObj))callback;
/**
Connect the peripheral you want
 @warning
 Only the new BLE protocol can get the WiFi list around the device and get WiFi information.
@param ssid WiFi name string.
@param password password string.
@param auth auth.
@param encry encry.
@param callback connect result callback.
*/
- (void)connectWLAN:(NSString *)ssid
           password:(NSString *)password
               auth:(NSString *)auth
               encry:(NSString *)encry
            callback:(void(^)(LP_CONNECT_AP_STATE code, id _Nullable responseObj))callback;
/*
Cancel the connection to the WiFi. If the UI layer sets a connection timeout during the network configuration process, pay attention to calling this method to destroy the callback.Prevents callbacks from causing UI interface confusion.
*/
- (void)cancelConnectWiFi;

/**
 Continue Scan BLE and not clean the cache
 
 @param callback Search BLE device list callback.
 */
- (void)continueScanBLEDeivce:(void (^)(NSArray * _Nullable BLEDeviceList))callback;
/// Send data to device via BLE
/// @param data data
/// @param cmdCode cmdCode
/// @param timeout timeout
/// @param callback callback
- (void)writeCharacter:(NSData *)data
               cmdCode:(uint16_t)cmdCode timeout:(NSTimeInterval)timeout
              callback:(void(^)(LP_BLE_ERROR_CODE code, uint16_t cmdCode, id _Nullable responseObj))callback;

- (void)setDebugLogOn:(BOOL)logOn;

@end

NS_ASSUME_NONNULL_END
