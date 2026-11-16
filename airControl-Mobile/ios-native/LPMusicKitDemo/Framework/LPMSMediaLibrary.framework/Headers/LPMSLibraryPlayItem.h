//
//  LPMSLibraryPlayItem.h
//  LPMediaLibraryKit
//
//  Created by sunyu on 2020/2/20.
//  Copyright © 2020 Linkplay. All rights reserved.
//

#import <LPMDPKit/LPMDPKit.h>
#import <MediaPlayer/MediaPlayer.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPMSLibraryPlayItem : LPPlayItem
@property (nonatomic,copy) NSString *_Nullable listName;        /** 歌单名称 */
@property (nonatomic, strong) MPMediaItem *_Nullable mediaItem; /** 用来获取图片 */
@property (nonatomic, strong) MPMediaItemCollection *_Nullable albumCollection; /** 专辑对象 */
@end

NS_ASSUME_NONNULL_END
