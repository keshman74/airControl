//
//  LPAlexaLoginView.h
//  LPAlexaKit
//
//  Created by sunyu on 2019/7/30.
//  Copyright © 2019 Linkplay. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <LPMusicKit/LPDevice.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LPAlexaLoginDelegate <NSObject>

@optional
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler;

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation;

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error;

- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error;

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation;

- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler;

/// 网页点击Cancel
- (void)cancel;

/// 网页登录成功
- (void)loginSuccess;

@end

@interface LPAlexaLoginView : UIView

@property (nonatomic, weak) id <LPAlexaLoginDelegate> delegate;

/// 初始化网页登录
/// @param frame 网页Frame 一般是全屏
/// @param device 设备对象
/// @param isBeta 是否是BETA版本
/// @param betaString 如果是Beta版本，默认的值是@"_BETA",
- (instancetype)initAlexaLoginViewWithFrame:(CGRect)frame device:(LPDevice *)device isBeta:(BOOL)isBeta betaString:(NSString *)betaString;

@end

NS_ASSUME_NONNULL_END
