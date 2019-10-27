#import "BTWebViewController.h"
#import "BTThreeDSecureLocalizedString.h"

static NSString *BTWebViewControllerPopupOpenDummyURLScheme = @"com.braintreepayments.popup.open";
static NSString *BTWebViewControllerPopupCloseDummyURLScheme = @"com.braintreepayments.popup.close";

@protocol BTThreeDSecurePopupDelegate <NSObject>

- (void)popupWebViewViewControllerDidFinish:(BTWebViewController *)viewController;

@end

@interface BTWebViewController () <WKNavigationDelegate, BTThreeDSecurePopupDelegate>

@property (nonatomic, strong) WKWebView *webView;

@property (nonatomic, weak) id<BTThreeDSecurePopupDelegate> delegate;

@end

@implementation BTWebViewController

- (instancetype)initWithCoder:(__unused NSCoder *)decoder {
    @throw [[NSException alloc] initWithName:@"Invalid initializer" reason:@"Use designated initializer" userInfo:nil];
}

- (instancetype)initWithNibName:(__unused NSString *)nibName bundle:(__unused NSBundle *)nibBundle {
    @throw [[NSException alloc] initWithName:@"Invalid initializer" reason:@"Use designated initializer" userInfo:nil];
}

- (instancetype)initWithRequest:(NSURLRequest *)request {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.webView = [[WKWebView alloc] init];
        self.webView.accessibilityIdentifier = @"Web View";
        [self.webView loadRequest:request];
    }
    return self;
}

- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id<BTThreeDSecurePopupDelegate>)delegate {
    self = [self initWithRequest:request];
    if (self) {
        self.delegate = delegate;
    }
    return self;
}

- (void)setDelegate:(id<BTThreeDSecurePopupDelegate>)delegate {
    _delegate = delegate;
    if (delegate) {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:BTThreeDSecureLocalizedString(ERROR_ALERT_CANCEL_BUTTON_TEXT) style:UIBarButtonItemStyleDone target:self action:@selector(informDelegateDidFinish)];
    }
}

- (void)loadView {
    self.view = self.webView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.webView.navigationDelegate = self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self updateNetworkActivityIndicatorForWebView:self.webView];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.webView stopLoading];
    [self updateNetworkActivityIndicatorForWebView:self.webView];
}

- (void)updateNetworkActivityIndicatorForWebView:(WKWebView *)webView {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:webView.isLoading];
}


#pragma mark Delegate Informers

- (void)informDelegateDidFinish {
    if ([self.delegate respondsToSelector:@selector(popupWebViewViewControllerDidFinish:)]) {
        [self.delegate popupWebViewViewControllerDidFinish:self];
    }
}


#pragma mark WKWebViewDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *requestURL = request.URL;
    if ([self isURLPopupOpenLink:requestURL]) {
        [self openPopupWithURLRequest:request];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    } else if ([self isURLPopupCloseLink:requestURL]) {
        [self informDelegateDidFinish];
        decisionHandler(WKNavigationActionPolicyCancel);
        return;
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void) webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    [self updateNetworkActivityIndicatorForWebView:webView];
    [self parseTitleFromWebView:webView];
    decisionHandler(WKNavigationResponsePolicyAllow);
}

- (void) webView:(WKWebView *)webView didFinishNavigation:(null_unspecified WKNavigation *)navigation {
    [self updateNetworkActivityIndicatorForWebView:webView];
    [self prepareTargetLinks:webView];
    [self prepareWindowOpenAndClosePopupLinks:webView];
    [self parseTitleFromWebView:webView];
}

- (void) webView:(WKWebView *)webView didFailNavigation:(null_unspecified WKNavigation *)navigation withError:(NSError *)error {
    if ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102) {
        // Not a real error; occurs when webView:shouldStartLoadWithRequest:navigationType: returns NO
        return;
    } else {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
        if (@available(iOS 8.0,*)) {
#else
        if ([UIAlertController class]) {
#endif
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:error.localizedDescription
                                                                           message:nil
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:BTThreeDSecureLocalizedString(ERROR_ALERT_OK_BUTTON_TEXT)
                                                      style:UIAlertActionStyleCancel
                                                    handler:^(__unused UIAlertAction *action) {
                                                    }]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [[[UIAlertView alloc] initWithTitle:error.localizedDescription
                                        message:nil
                                       delegate:nil
                              cancelButtonTitle:BTThreeDSecureLocalizedString(ERROR_ALERT_OK_BUTTON_TEXT)
                              otherButtonTitles:nil] show];
#pragma clang diagnostic pop
        }
    }
}


#pragma mark Web View Inspection

- (void)parseTitleFromWebView:(WKWebView *)webView {
    [webView evaluateJavaScript:@"document.title" completionHandler:^(NSString *title, NSError *error) {
        self.title = title;
    }];
}


#pragma mark Web View Popup Links

- (void)prepareTargetLinks:(WKWebView *)webView {
    NSString *js = [NSString stringWithFormat:@"var as = document.getElementsByTagName('a');\
                    for (var i = 0; i < as.length; i++) {\
                    if (as[i]['target']) { as[i]['href'] = '%@+' + as[i]['href']; }\
                    }\
                    true;", BTWebViewControllerPopupOpenDummyURLScheme];
    [webView evaluateJavaScript:js completionHandler:nil];
}

- (void)prepareWindowOpenAndClosePopupLinks:(WKWebView *)webView {
    NSString *js = [NSString stringWithFormat:@"(function(window) {\
                    function FakeWindow () {\
                    var fakeWindow = {};\
                    for (key in window) {\
                    if (typeof window[key] == 'function') {\
                    fakeWindow[key] = function() { console.log(\"FakeWindow received method call: \", key); };\
                    }\
                    }\
                    return fakeWindow;\
                    }\
                    function absoluteUrl (relativeUrl) { var a = document.createElement('a'); a.href = relativeUrl; return a.href; }\
                    window.open = function (url) { window.location = '%@+' + absoluteUrl(url); return new FakeWindow(); };\
                    window.close = function () { window.location = '%@://'; };\
                    })(window)", BTWebViewControllerPopupOpenDummyURLScheme, BTWebViewControllerPopupCloseDummyURLScheme];
    [webView evaluateJavaScript:js completionHandler:nil];
}

- (BOOL)isURLPopupOpenLink:(NSURL *)URL {
    NSString *schemePrefix = [[URL.scheme componentsSeparatedByString:@"+"] firstObject];
    return [schemePrefix isEqualToString:BTWebViewControllerPopupOpenDummyURLScheme];
}

- (BOOL)isURLPopupCloseLink:(NSURL *)URL {
    NSString *schemePrefix = [[URL.scheme componentsSeparatedByString:@"+"] firstObject];
    return [schemePrefix isEqualToString:BTWebViewControllerPopupCloseDummyURLScheme];
}

- (NSURL *)extractPopupLinkURL:(NSURL *)URL {
    NSURLComponents *c = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
    c.scheme = [[URL.scheme componentsSeparatedByString:@"+"] lastObject];
    
    return c.URL;
}

- (void)openPopupWithURLRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableRequest = request.mutableCopy;
    mutableRequest.URL = [self extractPopupLinkURL:request.URL];
    request = mutableRequest.copy;
    BTWebViewController *popup = [[BTWebViewController alloc] initWithRequest:request delegate:self];
    UINavigationController *navigationViewController = [[UINavigationController alloc] initWithRootViewController:popup];
    [self presentViewController:navigationViewController animated:YES completion:nil];
}


#pragma mark delegate

- (void)popupWebViewViewControllerDidFinish:(BTWebViewController *)viewController {
    [viewController dismissViewControllerAnimated:YES completion:nil];
}

@end
