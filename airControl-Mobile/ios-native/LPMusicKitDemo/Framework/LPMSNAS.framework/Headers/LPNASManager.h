//
//  LPNASManager.h
//  LPMSNAS
//
//  Created by sunyu on 2019/7/29.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <LPMusicKit/LPMediaServer.h>
#import <LPMDPKit/LPPlayHeader.h>
#import <LPMDPKit/LPPlayItem.h>
#import <LPMDPKit/LPPlayMusicList.h>

NS_ASSUME_NONNULL_BEGIN

/// NAS 对象的集合，可以通过getList 获取到路由中的NAS设备对象
@interface LPNASItem : LPPlayHeader
@property (nonatomic, copy) NSString *title;   // 名称
@property (nonatomic, copy) NSString *mediaID; //ID
@end

/// NAS 设备内容的对象，当你选择NAS设备后，可以通过searchMusic接口返回的LPPlayMusicList对象中的list属性中得到
@interface LPNASPlayItem : LPPlayItem
// 是否是文件夹，NAS设备内容可以是一层层的文件夹，如果是文件夹，需要继续调用searchMusic，直到内容是非文件夹，这样才能拿到歌曲
@property (nonatomic, readonly) BOOL isDirectory;
@property (nonatomic, readonly) NSString *mediaID; // ID
@end

@interface LPNASManager : NSObject
// 回调Block
typedef void (^LPNASItemsBlock)(BOOL isSuccess, LPPlayMusicList* _Nullable musicListObj);

+ (LPNASManager *)sharedInstance;

@property (nonatomic, readonly) NSString *version;

- (int)getCount;

- (NSArray<LPNASItem *> *)getList;
/// 获取NAS内部内容的方法，LPNASItem可以提供分页功能，每个LPNASItem对应多层NAS内容，该方法可以重复调用，直到拿到歌曲
/// @param item NAS 对象，currentPage等属性可以提供分页功能
/// @param playItem 第一次调用时，可以传递空对象，随着NAS内容分级，然后把LPPlayMusicList中的list对象，传递进来，isDirectory 是表明是否是文件夹，如果是文件，可以显示title，如果不是文件夹就是歌曲，可以展示album，artist 等属性
/// @param completionHandler 结果
- (void)searchMusic:(LPNASItem *)item playItem:(LPNASPlayItem *)playItem completionHandler:(LPNASItemsBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
