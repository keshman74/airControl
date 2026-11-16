//
//  LPDevicePreset.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^LPGetPresetBlock)(int presetNumber, NSString * _Nullable presetString);

typedef void (^LPPresetBlock)(BOOL isSuccess);

NS_ASSUME_NONNULL_BEGIN

/// Device preset
@interface LPDevicePreset : NSObject

- (LPDevicePreset *)initWithUUID:(NSString *)uuid;
/// Set preset content
/// @param infomation Preset information
/// @param completionHandler Callback
- (void)setPresetWithInfomation:(NSDictionary *)infomation completionHandler:(LPPresetBlock _Nullable)completionHandler;
/// Get a list of presets
/// @param completionHandler Callback
- (void)getPresets:(LPGetPresetBlock _Nullable)completionHandler;
/// Delete preset content
/// @param infomation Preset information
/// @param completionHandler Callback
- (void)deletePresetWithInfomation:(NSDictionary *)infomation completionHandler:(LPPresetBlock _Nullable)completionHandler;
/// 播放预置歌曲
/// @param index Index of preset objects
/// @param completionHandler 结果
- (void)playPresetWithIndex:(NSInteger)index completionHandler:(LPPresetBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
