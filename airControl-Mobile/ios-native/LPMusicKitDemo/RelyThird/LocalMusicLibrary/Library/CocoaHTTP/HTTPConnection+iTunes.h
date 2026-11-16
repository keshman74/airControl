//
//  HTTPConnection+iTunes.h
//  wAudioShare
//
//  Created by 赵帅 on 14-4-13.
//  Copyright (c) 2014年 赵帅. All rights reserved.
//

#import "HTTPConnection.h"

@interface HTTPConnection (iTunes)

-(void)prepareITunesFile:(NSString *)uri;

@end
