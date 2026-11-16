//
//  LPPassthrough.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*
 * Notification management
 * Please implement the following two notifications
 */
// Connection status changes
#define LPPassthroughConnectionStateChanged @"LPPassthroughConnectionStateChanged"
// Data returned by socket
#define LPPassThroughMessageCome @"LPPassThroughMessageCome"

@interface LPPassthrough : NSObject

- (LPPassthrough *)initWithUUID:(NSString *)uuid;
/// Establish a connection
- (void)connect;
/// Disconnect
- (void)disConnect;
/// Send data
/// @param cmd Sent data
- (void)write:(NSString *)cmd;

@end

NS_ASSUME_NONNULL_END
