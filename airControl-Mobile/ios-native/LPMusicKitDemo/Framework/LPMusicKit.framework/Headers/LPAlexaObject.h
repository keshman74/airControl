//
//  LPAlexaObject.h
//  LPMusicKit
//
//  Created by sunyu on 2019/7/30.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <Foundation/Foundation.h>
@class LPDevice;

NS_ASSUME_NONNULL_BEGIN

@interface LPAlexaObject : NSObject

- (void)isAlexaLogin:(LPDevice *)device completionHandler:(LPSDKReturnBlock _Nullable)completionHandler;

@end

NS_ASSUME_NONNULL_END
