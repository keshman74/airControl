//
//  LPDeviceSettings.h
//  LPMusicKit
//
//  Created by sunyu on 2020/7/1.
//  Copyright © 2020 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPDeviceSettings : NSObject

- (LPDeviceSettings *)initWithUUID:(NSString *)uuid;

/// Rename device
/// @param deviceName DeviceName
/// @param completionHandler Callback
- (void)setDeviceName:(NSString *)deviceName completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

/// Reset device
/// @param completionHandler Callback
- (void)resetDeviceWithHandler:(LPSDKReturnBlock _Nullable)completionHandler;

/// Input Mode array supported by the device, the content is the number corresponding to the LPInputSource type
/**
 typedef enum{
     LPLineIn,       // 0
     LPBluetooth,    // 1
     LPUSB,          // 2
     LPRadio,        // 3
     LPRCA,          // 4
     LPHDMI,         // 5
     LPOptical,      // 6
     LPWiFi,         // 7
     LPTFCard,       // 8
     LPXLR           // 9
 } LPInputSource;
 */
- (NSArray *)getSupportInputSource;
/// Switch device input source
/// @param source LPInputSource
/// @param completionHandler Callback
- (void)switchInputSource:(LPInputSource)source  completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

/**
 Get the supported EQ type and current Value.
 After modifying the value of EQ in other ways, you can synchronize the Value through the LPEQValueChangeNotification notification
 The data structure is as follows:
 {
     "Mode":"POP",
     "Version":1,
     "EQValue": @[
         @{@"Name":@"BandBASS", @"Value":@"0"},
         @{@"Name":@"BandLOW", @"Value":@"0"},
         @{@"Name":@"BandMID", @"Value":@"0"},
         @{@"Name":@"BandHIGH", @"Value":@"0"},
         @{@"Name":@"BandTREBLE", @"Value":@"0"}
         ...
     ]
 }
The array corresponding to the EQValue field is a collection of EQ types supported by the device. If there is a special EQ type, please contact Linkplay firmware personnel to configure the server data parameters.
 Generally, the value of Value is -5 to 5, please make sure that the value of Value is of type int.
 */
- (void)getSupportEQAndValues:(LPSDKReturnBlock _Nullable)completionHandler;

/// Set the value of each EQ type
/// @param valuesDict The data structure of EQValue returned by the getSupportEQAndValues interface
/// @param completionHandler Callback
- (void)setEQValues:(NSDictionary *)valuesDict completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;
/**
 * Hide or open the SSID of the device
 * When you turn on the device SSID, if there is no password, it is best to prompt the user to set the password, please call the setSSIDPassword method. You can judge whether the SSID has been hidden according to the isSSIDHidden attribute in deviceStatus
 */
/// @param hide Hide or open
/// @param completionHandler Callback
- (void)hideSSID:(BOOL)hide completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

/// Set the device SSID password, please note that the password length is at least 8 digits
/// @param password SSID password, at least 8 digits in length
/// @param completionHandler Callback
- (void)setSSIDPassword:(NSString *)password completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
