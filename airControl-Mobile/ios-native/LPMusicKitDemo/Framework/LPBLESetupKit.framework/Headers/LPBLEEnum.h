//
//  LPBLEEnum.h
//  iMuzo
//
//  Created by linkplay on 2019/12/21.
//  Copyright © 2019 wiimu. All rights reserved.
//

#ifndef LPBLEEnum_h
#define LPBLEEnum_h

/*
Send data to BLE device, the status code returned by the device.
*/
typedef NS_ENUM(NSUInteger, LP_BLE_ERROR_CODE) {
    LP_BLE_NO_ERROR = 0,  //No error
    LP_BLE_INVALID_CMD,  //Invalid command code
    LP_BLE_INVALID_DATA_PACKET,  //Invalid data packet format
    LP_BLE_PARAM_LEN_OUT_OF_RANGE,  //Parameter length out of range
    LP_BLE_PARAM_LEN_TOO_SHORT,  //Parameter length too short
    LP_BLE_CMD_HANDLING_FAILED,  //Command handling failed
    LP_BLE_WAITING_RSP_TIMEOUT,  //Waiting response time-out
    LP_BLE_DATA_XFER_ALREADY_STARTED,  //The data transfer has already been started
    LP_BLE_DATA_XFER_NOT_STARTED_YET,  //The data transfer hasn’t been started
    LP_BLE_DATA_SEGMENT_CRC_CHECK_FAILED,  //Data segment CRC check failed
    LP_BLE_WHOLE_DATA_CRC_CHECK_FAILED,  //Whole data CRC check failed
    LP_BLE_DATA_XFER_LEN_NOT_MATCHED,  //The data transfer length doesn’t match the actually received data length
};

/*
Result of device connected to WiFi via BLE.
*/
typedef NS_ENUM(NSUInteger, LP_BLE_CONNECT_RESULT) {
    LP_BLE_CONNECT_SUCCESS,
    LP_BLE_CONNECT_FAIL,
};

/*
Results of BLE device connected to WiFi
*/
typedef NS_ENUM(NSUInteger, LP_CONNECT_AP_STATE) {
    LP_CONNECT_AP_SUCCESS,
    LP_CONNECT_AP_START,
    LP_CONNECT_AP_NO_SSID,  //Have not scanned the specified SSID
    LP_CONNECT_AP_WIFI_TIMEOUT,  //WIFI connection timeout
    LP_CONNECT_AP_DHCP_TIMEOUT,  //DHCP timeout
    LP_CONNECT_AP_PASSWORD_ERROR,  //The password you entered is incorrect
    LP_CONNECT_AP_NO_SUPPORT_SECRET,  //Unsupported router encryption protocol
    LP_CONNECT_AP_PARAMETER_ERROR,  //Parameter error
    LP_CONNECT_AP_OTHER_ERROR,  //Other errors
    LP_CONNECT_AP_APP_CONNECT_OTHER_AP,  //Device and phone are not under the same router. Note: SDK cannot provide this judgment for the time being.
};

/*
Used with BLEProtocolType to determine the encryption method in BLE transmission.
*/
typedef NS_ENUM(NSUInteger, LPBLEProtocolVersion) {
    LPBLEProtocolVersion1_0_1,
    LPBLEProtocolVersion1_0_2,
    LPBLEProtocolVersion1_0_3,
};

/*
BLE protocol type used by the device.
*/
typedef NS_ENUM(NSUInteger, LPBLEProtocolType) {
    LPBLEProtocolType1,           // BLE1.0
    LPBLEProtocolType2,           // BLE2.0
};

#endif /* LPBLEEnum_h */
