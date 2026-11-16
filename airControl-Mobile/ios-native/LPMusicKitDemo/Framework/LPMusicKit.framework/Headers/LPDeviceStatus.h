//
//  LPDeviceStatus.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef enum
{
    LPChannel_stereo,   // Stereo
    LPChannel_left,     // Left channel
    LPChannel_right     // Right channel
}LPDeviceChannel;

typedef enum
{
    LP_ROOM_MASTER,     // Master speaker
    LP_ROOM_SLAVE       // Slave speaker
}LPRoomState;

typedef enum
{
    LPSecurityNone,
    LPSecurityHttps,
    LPSecurityHttps2
}LPSecurityType;

typedef enum{
    LPLineIn = 0,
    LPBluetooth,
    LPUSB,
    LPRadio,
    LPRCA,
    LPHDMI,
    LPOptical,
    LPWiFi,
    LPTFCard,
    LPXLR
} LPInputSource;

@interface LPDeviceStatus : NSObject

@property (nonatomic, readonly) NSString *MAC;              // Device MAC address
@property (nonatomic, readonly) NSString *productName;      // Device project
@property (nonatomic, readonly) NSString *nativeUUID;
@property (nonatomic, readonly) NSString *alexa_ver;        // Determine whether the device supports alexa
@property (nonatomic, readonly) NSString *tvs_ver;
@property (nonatomic, readonly) NSString *dueros_ver;
@property (nonatomic, strong) NSDictionary *deviceInfoDictionary; // Device Information
@property (nonatomic, copy) NSString *UUID;                 // Device UUID
@property (nonatomic, copy) NSString *IP;                   // Device IP
@property (nonatomic, copy) NSString *SSID;                 // Device SSID
@property (nonatomic, copy) NSString *friendlyName;         // Device name
@property (nonatomic, copy) NSString *groupName;
@property (nonatomic, copy) NSString *firmware;             // Firmware version
@property (nonatomic, copy) NSString *MCUVersion;             // MCU version
@property (nonatomic, copy) NSString *password;             // Password corresponding to the SSID of the device
@property (nonatomic, copy, nullable) NSString * masterID;  // UUID of the master device corresponding to the slave device
@property (nonatomic, copy) NSString *WifiChannel;
@property (nonatomic, copy) NSString *netstat;              // Device network status
@property (nonatomic, copy) NSString *language;             // Device language
@property (nonatomic, assign) CGFloat volume;               // Device volume
// Judge if the device has a network, if the device network changes, it will trigger the notification LPInternetAccessChange, at this time the value of isHaveInternet has been updated.
@property (nonatomic, assign) BOOL isHaveInternet;

@property (nonatomic, assign) NSTimeInterval relativeTime;  // The current playing time of the song
@property (nonatomic, assign) NSTimeInterval trackDuration; // Total song time
@property (nonatomic, assign) LPDeviceChannel currentChannel; // Device Current Channel
@property (nonatomic, assign) LPRoomState roomState;        // Whether the device is a master device or a slave device

@property (nonatomic, assign) BOOL isBackupState;           // Whether the device is in backup state
@property (nonatomic, assign) BOOL firmwareNeedUpdate;      // Does the firmware need to be upgraded
@property (nonatomic, copy) NSString *ota_interface_ver;
@property (nonatomic, copy) NSString *RSSI;                 // RSSI
@property (nonatomic, assign) int packVersion;              // upnp_version
@property (nonatomic, assign) int tcp_interface_port;       // Device socket port
@property (nonatomic, assign) int port;
@property (readonly, assign) BOOL spotify_active;
@property (readonly, assign) BOOL bluetooth_active;         // Whether it is Bluetooth mode
@property (nonatomic, assign) BOOL maybeIllegal;            // Whether the device is available
@property (nonatomic, assign) BOOL isCharging;              // Whether the device is charging
@property (nonatomic, copy) NSString *firmwareNewVersion;   // Firmware new version
@property (nonatomic, copy) NSString *DSPNewVersion;        // DSP new version
@property (nonatomic, copy) NSString *MCUNewVersion;        // MCU new version
@property (nonatomic, copy) NSString *MRMVersion;           // Device MRM version
@property (nonatomic, assign) BOOL isSSIDHidden;            // Whether to hide SSID
@property (nonatomic, assign) LPInputSource currentInputMode; // Device current input mode

#ifndef LINKPLAY_PUBLIC_HEADER
@property (nonatomic, assign) BOOL preventRoomStateUpdate;
@property (nonatomic, copy) NSString *sourceCmdText;
@property (nonatomic, assign) unsigned int streams;//支持的内容字段
@property (nonatomic, assign) unsigned int streams_all;//新的支持的内容字段，新固件优先使用这个字段，若没有，则使用streams
@property (nonatomic, assign) unsigned int languages;//设备支持的语言的能力
@property (nonatomic, assign) unsigned int plms;//支持的输入模式字段
@property (nonatomic, assign) unsigned int capability;//设备支持的能力
@property (nonatomic, assign) unsigned int cap1;//ggmm是否显示时钟
@property (nonatomic, assign) unsigned int external;//预留字段
@property (nonatomic, assign) int slaveMask;
@property (nonatomic, assign) int volumeTimeStamp;
@property (nonatomic, assign) int uart_pass_port;
@property (nonatomic, assign) int batteryElectricity;
@property (nonatomic, assign) int battery_mains;
@property (nonatomic, assign) int preset_key;

@property (nonatomic, copy) NSString *iheartradio_new; // 判断iheartradio 是否新版本，新版本，新的URL
@property (nonatomic,copy) NSString *NewTuneInPreset; //判断是否支持NewTuneIn的预置、闹钟
@property (readonly, assign) NSString *productID;
@property (readonly, assign) int sortNumber;//用于排序
@property (readonly, assign) BOOL isAliDevice;
@property (nonatomic, assign) BOOL preventVolumeNetUpdate;
@property (nonatomic, assign) BOOL preventProgressNetUpdate;
@property (nonatomic, assign) BOOL preventMediaInfoNetUpdate;
@property (nonatomic, assign) BOOL needResetTimeStamp;
@property (nonatomic, assign) BOOL isMask;
@property (nonatomic, assign) BOOL isSecurity3;
@property (nonatomic, assign) BOOL privacy_mode;
@property (nonatomic, assign) BOOL isFirmwareExpired;
@property (nonatomic, retain) NSDate *foundDate;
@property (nonatomic, assign) LPSecurityType deviceSecurityType;

#endif

- (void)setDeviceStatusWithDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
