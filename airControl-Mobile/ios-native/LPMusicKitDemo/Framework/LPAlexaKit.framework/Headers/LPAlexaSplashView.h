//
//  LPAlexaSplashView.h
//  LPAlexaKit
//
//  Created by sunyu on 2019/7/29.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <LPMusicKit/LPDevice.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LPAlexaSplashDelegate <NSObject>

@optional
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation;

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error;

// 网页点击登录
- (void)login;

/// 网页点击Skip 或者返回按键
- (void)skip;

@end

@interface LPAlexaSplashView : UIView

@property (nonatomic, weak) id <LPAlexaSplashDelegate> delegate;

/// 初始化Splash 网页
/// @param frame 网页Frame 一般是全屏
/// @param device 设备对象
- (instancetype)initAlexaSplashViewWithFrame:(CGRect)frame device:(LPDevice *)device;

@end

NS_ASSUME_NONNULL_END
