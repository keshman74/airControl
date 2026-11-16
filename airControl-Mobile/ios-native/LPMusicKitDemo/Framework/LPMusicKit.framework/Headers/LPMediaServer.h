//
//  LPMediaServer.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPMediaObj : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *mediaID;
@property (nonatomic, copy) NSString *serverIndex;

@end

@interface LPMediaItem : NSObject

@property (nonatomic, readonly) BOOL isDirectory;
@property (nonatomic, readonly) NSString *mediaID;

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *artist;
@property (nonatomic, readonly) NSString *album;
@property (nonatomic, readonly) NSString *artworkURL;
@property (nonatomic, readonly) NSString *URL;

@end

typedef void (^LPMediaItemsBlock)(BOOL isSuccess, NSArray <LPMediaItem *>* _Nullable LPMediaItems);


@interface LPMediaServer : NSObject

- (NSArray<LPMediaObj *> *)getList;

- (int)getCount;

- (void)searchMusic:(LPMediaObj *)mediaObj currentIndex:(int)currentIndex maxIndex:(int)maxIndex completionHandler:(LPMediaItemsBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
