//
//  LPMediaInfo.h
//  LPMusicKit
//
//  Created by 许一宁 on 2019/7/15.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LPMediaInfo : NSObject

@property (nonatomic, copy) NSString *UUID;             // Device UUID
@property (nonatomic, copy, nullable) NSString *artist; // Artist name
@property (nonatomic, copy, nullable) NSString *album;  // The album name
@property (nonatomic, copy, nullable) NSString *title;  // Name of the song
@property (nonatomic, copy, nullable) NSString *artworkUri; // Picture URL
@property (nonatomic, copy, nullable) NSString *stationID;   // iheartradio的stationID
@property (nonatomic, copy) NSString *mediaType;        // Media type
@property (nonatomic, copy) NSString *trackSource;      // Media resources
@property (nonatomic ,copy) NSString *songId;           // Song id
@property (nonatomic, copy) NSString *subStationID;     // subStationID
@property (nonatomic, copy) NSString *albumID;          // Album ID
@property (nonatomic, copy) NSString *artistID;         // Artist ID
@property (nonatomic, copy) NSString *skiplimit;


@property (nonatomic, copy) NSString *typeDescription;
@property (nonatomic, copy) NSString *metaDataString;
//alexa
@property (nonatomic, copy) NSString *controllerHex;
@property (nonatomic, copy) NSString *svgImageUrl;

//prime music
@property (nonatomic, copy, nullable) NSString *ratingURI;

@property (nonatomic, assign) BOOL songliked;
//new_TuneIn
@property (assign, nonatomic) BOOL isLive; //Live
@property (assign, nonatomic) BOOL canPlay;//Can it be played
@property (assign, nonatomic) BOOL isFollowing;//Like
@property (nonatomic, copy, nullable) NSString *subtitle;
@property (nonatomic, copy, nullable) NSString *playErrorCode;
@property (nonatomic, copy, nullable) NSString *playErrorMessage;
@property (nonatomic, copy) NSString *searchUrl;

@property (nonatomic, assign) int quality;
@property (nonatomic, retain, nullable) NSNumber *persistentID;
@property (nonatomic, retain, nullable) UIImage *artwork;

@property (nonatomic ,copy, nullable) NSString *controllerGUID;
@property (nonatomic ,copy, nullable) NSString *url;

- (void)setQPlayMetaDataString:(NSString *)metaDataString;

@end

NS_ASSUME_NONNULL_END
