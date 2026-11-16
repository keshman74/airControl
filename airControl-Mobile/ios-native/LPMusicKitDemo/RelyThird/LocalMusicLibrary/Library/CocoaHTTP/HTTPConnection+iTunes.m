//
//  HTTPConnection+iTunes.m
//  wAudioShare
//
//  Created by 赵帅 on 14-4-13.
//  Copyright (c) 2014年 赵帅. All rights reserved.
//

#import "HTTPConnection+iTunes.h"
#import "TSLibraryImport.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <LPMSMediaLibrary/LPMSMediaLibrary.h>

@implementation HTTPConnection (iTunes)

-(void)prepareITunesFile:(NSString *)uri
{
    NSURL * url = [NSURL URLWithString:uri relativeToURL:[NSURL fileURLWithPath:[config documentRoot] isDirectory:YES]];
    uri = [url relativeString];
    
    if([uri hasSuffix:@".m3u"])
    {
        return;
    }
    
    uri = [uri substringFromIndex:1];

    NSString * songName = nil;
    NSString * songName_url = nil;//经过url编码
    if([uri hasSuffix:@"_artwork"])
    {
        songName_url = [uri stringByReplacingOccurrencesOfString:@"_artwork" withString:@""];
    }
    else
    {
        songName_url = uri;
    }
    
    songName = [songName_url stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];//去除编码
    
    NSArray *arr = [LPMSLibraryManager sharedInstance].arrItunesMusic;
    NSURL *outURL = nil;

    for(MPMediaItem * mediaItem in arr)
    {
        if([songName isEqualToString:[NSString stringWithFormat:@"%@",[mediaItem valueForProperty:MPMediaItemPropertyPersistentID]]])
        {
            NSURL *assetURL = [mediaItem valueForProperty:MPMediaItemPropertyAssetURL];
            outURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingFormat:@"%@", uri]];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            if(![fileManager fileExistsAtPath:[NSTemporaryDirectory() stringByAppendingFormat:@"%@", uri]]) //如果不存在
            {
                if(![uri hasSuffix:@"_artwork"])
                {
                    __block BOOL isFinished = NO;
                    TSLibraryImport * tsImport = [[TSLibraryImport alloc] init];
                    
                    NSLog(@"******** copy %@ from %@ to %@, ask uri is %@,songName_url is %@",songName, [assetURL absoluteString],[outURL absoluteString],uri,songName_url);
                    
                    NSDate * date = [NSDate date];
                    
                    [tsImport importAsset:assetURL toURL:outURL completionBlock:^(TSLibraryImport *aIimport) {
                        NSLog(@"------ copy song cost %f",[[NSDate date] timeIntervalSinceDate:date]);
                        
                        isFinished = YES;
                        
                        if(aIimport == nil)
                        {
                            NSLog(@"--- Import error occurred");
                            return;
                        }
                        
                        if (aIimport.status != AVAssetExportSessionStatusCompleted) {
                            // something went wrong with the import
                            NSLog(@"Error importing: %@", aIimport.error);
                            
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"TSLIMPORTERROR" object:[NSNumber numberWithInt:importerror_unknown]];
                            
                            return;
                        }
                    }];
                    
                    while (isFinished == NO) {
                        [NSThread sleepForTimeInterval:0.1];
                    }
                }
                else
                {
                    UIImage *artworkImg = [[mediaItem valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(500, 500)];
                    if(artworkImg)
                    {
                        NSData * data = UIImagePNGRepresentation(artworkImg);
                        [data writeToFile:[NSTemporaryDirectory() stringByAppendingFormat:@"%@", uri] atomically:YES];
                    }
                }
            }
            
            return;
        }
    }
}

@end
