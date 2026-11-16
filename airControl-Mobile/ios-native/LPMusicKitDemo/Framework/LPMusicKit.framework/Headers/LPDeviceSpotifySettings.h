//
//  LPDeviceSpotifySettings.h
//  LPMusicKit
//
//  Created by sunyu on 2020/10/20.
//  Copyright © 2020 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPDeviceSpotifySettings : NSObject

- (LPDeviceSpotifySettings *)initWithUUID:(NSString *)uuid;

/// Judge whether the currently playing Spotify is a free account
- (BOOL)isFreeSpotifyAccount;
/// Judge whether the UI displays the Seek button
- (BOOL)isShowSpotifySeekButton;
/// Spotify seek enable
- (BOOL)spotifySeekEnable;
/// Spotify prev enable
- (BOOL)spotifyPrevEnable;
/// Spotify next enable
- (BOOL)spotifyNextEnable;

/// Spotify seek backward
- (void)spotifySeekBackward;
/// Spotify seek forward
- (void)spotifySeekForward;


@end

NS_ASSUME_NONNULL_END
