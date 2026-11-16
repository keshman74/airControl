//
//  LPDevicePlayer.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LPDeviceInfo.h"


typedef void (^LPPlayerBlock)(BOOL isSuccess, NSString * _Nullable result);

NS_ASSUME_NONNULL_BEGIN

/// Device's player.
@interface LPDevicePlayer : NSObject

- (LPDevicePlayer *)initWithUUID:(NSString *)uuid;
/// Play
/// @param completionHandler Callback
- (void)play:(LPPlayerBlock _Nullable)completionHandler;
/// Pause
/// @param completionHandler Callback
- (void)pause:(LPPlayerBlock _Nullable)completionHandler;
/// Stop
/// @param completionHandler Callback
- (void)stop:(LPPlayerBlock _Nullable)completionHandler;
/// Next
/// @param completionHandler Callback
- (void)next:(LPPlayerBlock _Nullable)completionHandler;
/// Previous
/// @param completionHandler Callback
- (void)previous:(LPPlayerBlock _Nullable)completionHandler;
/// Set play progress
/// @param progress Play progress
/// @param completionHandler Callback
- (void)setProgress:(NSTimeInterval)progress completionHandler:(LPPlayerBlock _Nullable)completionHandler;
/// Set sound channel
/// @param channel Sound channel
/// @param completionHandler Callback
- (void)setChannel:(LPDeviceChannel)channel completionHandler:(LPPlayerBlock _Nullable)completionHandler;
/// Play music
/// @param musicDictionary Media info to play, similar NSDictionary *info = [[LPMDPKitManager shared] playMusicSingleSource:listObj];
/// @param completionHandler Callback
- (void)playAudioWithMusicDictionary:(NSDictionary *)musicDictionary completionHandler:(LPPlayerBlock _Nullable)completionHandler;
/// Set play mode
/// @param playMode Play mode
- (void)setPlayMode:(LPPlayMode)playMode completionHandler:(LPPlayerBlock _Nullable)completionHandler;
/// Set Spotify play mode
/// @param spotifyPlayMode Play mode
- (void)setSpotifyPlayMode:(LPSpotifyPlayMode)spotifyPlayMode completionHandler:(LPPlayerBlock _Nullable)completionHandler;
/// Set volume
/// @param volume Device's volume
- (void)setVolume:(CGFloat)volume;
/// Delete a track from current playing list
/// @param index Index in the current playing list
/// @param completionHandler Callback
- (void)deleteWithIndex:(NSInteger)index completionHandler:(LPPlayerBlock _Nullable)completionHandler;

/// Query the list of currently playing songs
/// @param completionHandler Callback
- (void)queryCurrentPlayList:(LPPlayerBlock _Nullable)completionHandler;

/// Current song as the next song to play
/// @param musicDictionary Media info to play, similar NSDictionary *info = [[LPMDPKitManager shared] playMusicSingleSource:listObj];
/// @param completionHandler Callback
- (void)nextPlay:(NSDictionary *)musicDictionary completionHandler:(LPPlayerBlock _Nullable)completionHandler;

/// Play USB songs
/// @param index Song Index
/// @param completionHandler Callback
- (void)playUSBSongsWithIndex:(int)index completionHandler:(LPPlayerBlock _Nullable)completionHandler;

/// To play the songs in the current playlist, you only need the index of the song
/// @param index The index of the song in the current playlist (queryCurrentPlayList)
/// @param completionHandler Callback
- (void)playCurrentPlayListWithIndex:(int)index completionHandler:(LPPlayerBlock _Nullable)completionHandler;

/// Play playlist
/// @param queueName Playlist name
/// @param index The index of the song in the  playlist
/// @param completionHandler Callback
- (void)playQueueWithQueueName:(NSString *)queueName index:(int)index completionHandler:(LPPlayerBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
