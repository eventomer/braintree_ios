#import <UIKit/UIKit.h>
@import WebKit;
NS_ASSUME_NONNULL_BEGIN

@interface BTWebViewController : UIViewController

#pragma mark - Designated initializers

- (nonnull instancetype)initWithRequest:(nonnull NSURLRequest *)request NS_DESIGNATED_INITIALIZER;

#pragma mark - Undesignated initializers (do not use)

- (nullable instancetype)initWithCoder:(NSCoder *)decoder __attribute__((unavailable("Please use initWithRequest: instead.")));
- (instancetype)initWithNibName:(nullable NSString *)nibName bundle:(nullable NSBundle *)nibBundle __attribute__((unavailable("Please use initWithRequest: instead.")));

#pragma mark Override Points for Subclasses

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler __attribute__((objc_requires_super));
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler __attribute__((objc_requires_super));
- (void)webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation __attribute__((objc_requires_super));
- (void)webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
