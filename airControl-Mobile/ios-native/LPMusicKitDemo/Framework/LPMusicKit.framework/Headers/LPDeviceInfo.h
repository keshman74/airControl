//
//  LPDeviceInfo.h
//  wAudioShare
//
//  Created by 赵帅 on 14-5-7.
//  Copyright (c) 2014年 wiimu. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
    LP_PLAYER_STATE_PLAYING  = 0,       // Playing
    LP_PLAYER_STATE_STOPPED,            // Stop
    LP_PLAYER_STATE_PAUSED_PLAYBACK,    // Pause
    LP_PLAYER_STATE_TRANSITIONING,      // Transitioning
    LP_PLAYER_STATE_NO_MEDIA_PRESENT    // No media present
}LPPlayStatus;


typedef enum
{
    LP_SPOTIFY_LISTREPEAT = 0,            // Loop playback
    LP_SPOTIFY_SINGLEREPEAT = 1,          // Single cycle
    LP_SPOTIFY_SHUFFLEREPEAT =2,          // Shuffle repeat
    LP_SPOTIFY_SHUFFLE = 3,               // Shuffle
    LP_SPOTIFY_DEFAULT = 4,               // Default
    LP_SPOTIFY_SINGLE_REPEAT_SHUFFLE = 5  // Shuffle single repeat
}LPSpotifyPlayMode;

typedef enum
{
    LP_LISTREPEAT = 0,
    LP_SINGLEREPEAT,
    LP_SHUFFLE,
    LP_SHUFFLEREPEAT,
    LP_DEFAULT = 4
}LPPlayMode;

typedef void (^LPBrowseBlock)(id _Nullable obj, NSString * _Nullable resultString);

@class LPDevice;

@interface LPDeviceInfo : NSObject
/// Playing state
@property (nonatomic, assign) LPPlayStatus playStatus;
/// The Queue name that the current device is playing, you need to call updateCurrentPlayInfo method to get or update its value
@property (nonatomic, copy) NSString * _Nullable currentQueue;
/// The playback mode of the current device, a value of 4 means MRM plays music
@property (nonatomic, copy) NSString * _Nullable playType;
/// Index of the song currently playing on the device, you need to call updateCurrentPlayInfo method to get or update its value
@property (nonatomic, assign) int currentPlayIndex;
/// Spotify Play mode
@property (nonatomic, assign) LPSpotifyPlayMode spotifyPlayMode;
/// Play mode
@property (nonatomic, assign) LPPlayMode playMode;

// To determine the current display device, or to switch the current display device, you need to call this method once. Can be used to update the currentQueue and currentPlayIndex in deviceInfo
- (void)updateCurrentPlayInfo;

/// Browse device information, The result obtained can be obtained through [[LPMDPKitManager shared] getBrowseListWithString:result] to get the data interface
/// @param queueName The value is @"TotalQueue", @"CurrentQueue", @"USBDiskQueue" or the queue name of the playlist
/// @param skip The default is NO
/// @param completionHandler Callback
- (void)browseQueue:(NSString *_Nullable)queueName skipContent:(BOOL)skip completionHandler:(LPBrowseBlock _Nullable)completionHandler;

/// Delete queue
/// @param queueName queueName
/// @param completionHandler Callback
- (void)deleteQueue:(NSString *_Nullable)queueName completionHandler:(void (^_Nonnull)(BOOL isSuccess))completionHandler;

/// Create queue
/// @param queueContext playList XML string
/// @param completionHandler Callback
- (void)createQueue:(NSString *_Nullable)queueContext completionHandler:(void (^_Nonnull)(BOOL isSuccess))completionHandler;


#ifndef LINKPLAY_PUBLIC_HEADER
- (id _Nonnull )initWithSoundBox:(NSString *_Nonnull)soundBoxIdentity;
@property (nonatomic, assign) int playModeValue;
@property (nonatomic, copy) NSString * _Nonnull soundBoxIdentity;
@property (nonatomic, copy) NSString * _Nullable controllerGUID;
@property (assign, nonatomic) BOOL afterEnterforePlayStateNotChange;

- (void)stopUpdate;
- (void)startStateQueryThread;
- (void)stopStateQueryThread;
- (void)stateQueryMethod;

#endif



@end
