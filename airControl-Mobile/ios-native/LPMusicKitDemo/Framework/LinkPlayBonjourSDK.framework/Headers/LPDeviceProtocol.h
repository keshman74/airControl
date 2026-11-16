//
//  LPDeviceProtocol.h
//  BonjourSDK
//
//  Created by sunyu on 2018/12/20.
//  Copyright © 2018年 sunyu. All rights reserved.
//

#import <Foundation/Foundation.h>


@protocol LPDeviceProtocol <NSObject>

/// IP
@property (nonatomic, copy) NSString *ipString;
/// UUID
@property (nonatomic, copy) NSString * identity;
/// Host
@property (nonatomic, copy) NSString *hostName;
/// MAC
@property (nonatomic, copy) NSString *macName;
/// Security version
@property (nonatomic, copy) NSString *security;
/// Port
@property (nonatomic, copy) NSString *portString;
/// Device name
@property (nonatomic, copy) NSString * friendlyName;
/// Device bootId
@property (nonatomic, copy) NSString *bootId;
/// Device Version 5.0
@property (nonatomic, copy) NSString *version;
/// UPNP Version 1.0.0
@property (nonatomic, copy) NSString *upnpVersion;

@end
