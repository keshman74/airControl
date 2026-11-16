//
//  LPUSBManager.h
//  LPMusicKit
//
//  Created by sunyu on 2020/6/8.
//  Copyright © 2020 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^LPBrowseUSBBlock)(NSString * _Nullable result);
typedef void (^LPGetUSBStatusBlock)(BOOL isHaveUSB);

NS_ASSUME_NONNULL_BEGIN

@interface LPUSBManager : NSObject

+ (instancetype)sharedInstance;

/// Query the list of songs in USB
/// @param UUID Device UUID
/// @param completionHandler Callback
- (void)browseUSBWithID:(NSString *)UUID completionHandler:(LPBrowseUSBBlock _Nullable)completionHandler;

/// Check if the device is plugged into USB
/// @param UUID Device UUID
/// @param completionHandler Callback
- (void)getUSBDiskStatusWithID:(NSString *)UUID completionHandler:(LPGetUSBStatusBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
