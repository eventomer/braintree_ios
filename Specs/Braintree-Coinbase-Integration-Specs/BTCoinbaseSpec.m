#import <coinbase-official/CoinbaseOAuth.h>

#import "BTCoinbase.h"
#import "BTClient_Internal.h"

SpecBegin(BTCoinbase)

__block id coinbaseAppAuthenticationURLMatcher;
__block id coinbaseWebsiteAuthenticationURLMatcher;

before(^{
    coinbaseAppAuthenticationURLMatcher = [OCMArg checkWithBlock:^BOOL(id obj){
        NSURL *coinbaseAppSwitchURL = obj;
        BOOL schemeMatches = [[coinbaseAppSwitchURL scheme] isEqualToString:@"com.coinbase.oauth-authorize"];
        BOOL pathMatches = [[coinbaseAppSwitchURL path] isEqualToString:@"/oauth/authorize"];
        BOOL queryContainsScopes = [[coinbaseAppSwitchURL query] rangeOfString:@"test-coinbase-scopes"].location != NSNotFound;
        BOOL queryContainsClientId = [[coinbaseAppSwitchURL query] rangeOfString:@"test-coinbase-client-id"].location != NSNotFound;
        BOOL queryContainsMerchantAccount = [[coinbaseAppSwitchURL query] rangeOfString:@"coinbase-merchant-account%40test.example.com"].location != NSNotFound;

        return schemeMatches && pathMatches && queryContainsScopes && queryContainsClientId && queryContainsMerchantAccount;
    }];

    coinbaseWebsiteAuthenticationURLMatcher = [OCMArg checkWithBlock:^BOOL(id obj){
        NSURL *coinbaseAppSwitchURL = obj;
        BOOL schemeMatches = [[coinbaseAppSwitchURL scheme] isEqualToString:@"https"];
        BOOL hostMatches = [[coinbaseAppSwitchURL host] isEqualToString:@"www.coinbase.com"];
        BOOL pathMatches = [[coinbaseAppSwitchURL path] isEqualToString:@"/oauth/authorize"];
        BOOL queryContainsScopes = [[coinbaseAppSwitchURL query] rangeOfString:@"test-coinbase-scopes"].location != NSNotFound;
        BOOL queryContainsClientId = [[coinbaseAppSwitchURL query] rangeOfString:@"test-coinbase-client-id"].location != NSNotFound;
        BOOL queryContainsMerchantAccount = [[coinbaseAppSwitchURL query] rangeOfString:@"coinbase-merchant-account%40test.example.com"].location != NSNotFound;

        return schemeMatches && hostMatches && pathMatches && queryContainsScopes && queryContainsClientId && queryContainsMerchantAccount;
    }];
});

it(@"integrates coinbase sdk", ^{
    expect([CoinbaseOAuth class]).to.beKindOf([NSObject class]);
    expect(CoinbaseErrorDomain).to.beKindOf([NSString class]);
});

describe(@"sharedInstance", ^{
    it(@"returns an instance", ^{
        expect([BTCoinbase sharedCoinbase]).to.beKindOf([BTCoinbase class]);
    });

    it(@"implements a singleton", ^{
        expect([BTCoinbase sharedCoinbase]).to.beIdenticalTo([BTCoinbase sharedCoinbase]);
    });

    it(@"does not impact the designated initializer", ^{
        expect([[BTCoinbase alloc] init]).notTo.beIdenticalTo([BTCoinbase sharedCoinbase]);
    });
});

describe(@"BTAppSwitching", ^{
    describe(@"appSwitchAvailableForClient:", ^{
        it(@"returns YES if coinbase is enabled in the client configuration", ^{
            id clientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[clientToken stub] andReturnValue:@(YES)] coinbaseEnabled];

            id client = [OCMockObject mockForClass:[BTClient class]];
            [[[client stub] andReturn:clientToken] clientToken];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];

            expect([coinbase appSwitchAvailableForClient:client]).to.beTruthy();
        });

        it(@"returns NO if coinbase is disabled in the client configuration", ^{
            id clientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[clientToken stub] andReturnValue:@(NO)] coinbaseEnabled];

            id client = [OCMockObject mockForClass:[BTClient class]];
            [[[client stub] andReturn:clientToken] clientToken];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];

            expect([coinbase appSwitchAvailableForClient:client]).to.beFalsy();
        });
    });

    describe(@"initiateAppSwitchWithClient:", ^{
        it(@"switches to the coinbase app when it is available", ^{
            id clientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[clientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[clientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[clientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[clientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];

            id client = [OCMockObject mockForClass:[BTClient class]];
            [[[client stub] andReturn:clientToken] clientToken];

            id<BTAppSwitchingDelegate> delegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            id sharedApplicationStub = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
            [[[sharedApplicationStub expect] andReturnValue:@(YES)] canOpenURL:coinbaseAppAuthenticationURLMatcher];
            [[[sharedApplicationStub expect] andReturnValue:@(YES)] openURL:coinbaseAppAuthenticationURLMatcher];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];

            BOOL appSwitchInitiated = [coinbase initiateAppSwitchWithClient:client
                                                                   delegate:delegate
                                                                      error:NULL];
            expect(appSwitchInitiated).to.beTruthy();
            [sharedApplicationStub verify];
        });

        it(@"falls back to switching to Safari when the coinbase app is not available", ^{
            id clientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[clientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[clientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[clientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[clientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];

            id client = [OCMockObject mockForClass:[BTClient class]];
            [[[client stub] andReturn:clientToken] clientToken];

            id<BTAppSwitchingDelegate> delegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            id sharedApplicationStub = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
            [[[sharedApplicationStub stub] andReturnValue:@(NO)] canOpenURL:coinbaseAppAuthenticationURLMatcher];
            [[[sharedApplicationStub expect] andReturnValue:@(YES)] openURL:coinbaseWebsiteAuthenticationURLMatcher];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];

            BOOL appSwitchInitiated = [coinbase initiateAppSwitchWithClient:client
                                                                   delegate:delegate
                                                                      error:NULL];
            expect(appSwitchInitiated).to.beTruthy();
            [sharedApplicationStub verify];
        });

        it(@"fails when the developer has not yet provided a return url scheme", ^{
            id clientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[clientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[clientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[clientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[clientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];

            id client = [OCMockObject mockForClass:[BTClient class]];
            [[[client stub] andReturn:clientToken] clientToken];

            id<BTAppSwitchingDelegate> delegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            id sharedApplicationStub = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
            [[[sharedApplicationStub stub] andReturnValue:@(YES)] canOpenURL:[OCMArg any]];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];

            NSError *error;
            BOOL appSwitchInitiated = [coinbase initiateAppSwitchWithClient:client
                                                                   delegate:delegate
                                                                      error:&error];
            expect(appSwitchInitiated).to.beFalsy();
            expect(error.domain).to.equal(BTAppSwitchErrorDomain);
            expect(error.code).to.equal(BTAppSwitchErrorIntegrationReturnURLScheme);
            expect(error.localizedDescription).to.contain(@"Coinbase is not available");
            [sharedApplicationStub verify];
        });

        it(@"fails when the app switch fails", ^{
            id clientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[clientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[clientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[clientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[clientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];

            id client = [OCMockObject mockForClass:[BTClient class]];
            [[[client stub] andReturn:clientToken] clientToken];

            id<BTAppSwitchingDelegate> delegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            id sharedApplicationStub = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
            [[[sharedApplicationStub stub] andReturnValue:@(YES)] canOpenURL:[OCMArg any]];
            [[[sharedApplicationStub stub] andReturnValue:@(NO)] openURL:[OCMArg any]];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];

            NSError *error;
            BOOL appSwitchInitiated = [coinbase initiateAppSwitchWithClient:client
                                                                   delegate:delegate
                                                                      error:&error];
            expect(appSwitchInitiated).to.beFalsy();
            expect(error.domain).to.equal(BTAppSwitchErrorDomain);
            expect(error.code).to.equal(BTAppSwitchErrorFailed);
            expect(error.localizedDescription).to.contain(@"Coinbase is not available");
            [sharedApplicationStub verify];
        });

        it(@"accepts a NULL error even on failures", ^{
            id clientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[clientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[clientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[clientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[clientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];

            id client = [OCMockObject mockForClass:[BTClient class]];
            [[[client stub] andReturn:clientToken] clientToken];

            id<BTAppSwitchingDelegate> delegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            id sharedApplicationStub = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
            [[[sharedApplicationStub stub] andReturnValue:@(YES)] canOpenURL:[OCMArg any]];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];

            BOOL appSwitchInitiated = [coinbase initiateAppSwitchWithClient:client
                                                                   delegate:delegate
                                                                      error:NULL];
            expect(appSwitchInitiated).to.beFalsy();
            [sharedApplicationStub verify];
        });

        it(@"does not set an error on success", ^{
            id clientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[clientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[clientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[clientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[clientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];

            id client = [OCMockObject mockForClass:[BTClient class]];
            [[[client stub] andReturn:clientToken] clientToken];

            id<BTAppSwitchingDelegate> delegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            id sharedApplicationStub = [OCMockObject partialMockForObject:[UIApplication sharedApplication]];
            [[[sharedApplicationStub expect] andReturnValue:@(YES)] canOpenURL:coinbaseAppAuthenticationURLMatcher];
            [[[sharedApplicationStub expect] andReturnValue:@(YES)] openURL:coinbaseAppAuthenticationURLMatcher];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];

            NSError *error;
            BOOL appSwitchInitiated = [coinbase initiateAppSwitchWithClient:client
                                                                   delegate:delegate
                                                                      error:&error];
            expect(appSwitchInitiated).to.beTruthy();
            expect(error).to.beNil();
            [sharedApplicationStub verify];
        });
    });

    describe(@"canHandleReturnURL:sourceApplication:", ^{
        it(@"returns YES when the url matches the redirect URI regardless of the source application", ^{
            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];

            NSURL *testURL = [NSURL URLWithString:@"com.example.app.payments://x-callback-url/vzero/auth/coinbase/redirect?code=1234"];
            BOOL canHandleURL = [coinbase canHandleReturnURL:testURL sourceApplication:@"any source application"];

            expect(canHandleURL).to.beTruthy();
        });

        it(@"returns YES when the return url indicates an error", ^{
            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];

            NSURL *testURL = [NSURL URLWithString:@"com.example.app.payments://x-callback-url/vzero/auth/coinbase/redirect?error_message=1234&random=thing"];
            BOOL canHandleURL = [coinbase canHandleReturnURL:testURL sourceApplication:@"any source application"];

            expect(canHandleURL).to.beTruthy();
        });

        it(@"returns NO when the return url scheme has not been set", ^{
            BTCoinbase *coinbase = [[BTCoinbase alloc] init];

            NSURL *testURL = [NSURL URLWithString:@"com.example.app.payments://x-callback-url/vzero/auth/coinbase/redirect?code=1234"];
            BOOL canHandleURL = [coinbase canHandleReturnURL:testURL sourceApplication:@"any source application"];
            expect(canHandleURL).to.beFalsy();
        });

        it(@"returns NO when the url's scheme does not match the return url scheme", ^{
            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.other-app.payments"];

            NSURL *testURL = [NSURL URLWithString:@"com.example.app.payments://x-callback-url/vzero/auth/coinbase/redirect?code=1234"];
            BOOL canHandleURL = [coinbase canHandleReturnURL:testURL sourceApplication:@"any source application"];
            expect(canHandleURL).to.beFalsy();
        });

        it(@"returns NO when the path specifies a different payment option", ^{
            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];

            NSURL *testURL = [NSURL URLWithString:@"com.example.app.payments://x-callback-url/vzero/auth/venmo/success?key=value"];
            BOOL canHandleURL = [coinbase canHandleReturnURL:testURL sourceApplication:@"any source application"];
            expect(canHandleURL).to.beFalsy();
        });
    });

    describe(@"handleReturnURL:", ^{
        it(@"no-ops if the return URL cannot be handled according to canHandleReturnURL:sourceApplication:", ^{
            id mockDelegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];
            coinbase.delegate = mockDelegate;

            NSURL *testURL = [NSURL URLWithString:@"com.example.random-app://some/unrelated/url"];
            [coinbase handleReturnURL:testURL];

            [mockDelegate verifyWithDelay:10];
        });

        it(@"tokenizes the code returned by coinbase", ^{
            id mockClientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[mockClientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[mockClientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[mockClientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[mockClientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];
            id mockClient = [OCMockObject mockForClass:[BTClient class]];
            [[[mockClient stub] andReturn:mockClientToken] clientToken];
            BTCoinbasePaymentMethod *mockPaymentMethod = [OCMockObject mockForClass:[BTCoinbasePaymentMethod class]];

            [[[mockClient stub] andDo:^(NSInvocation *invocation){
                BTClientCoinbaseSuccessBlock successBlock = [invocation getArgumentAtIndexAsObject:3];
                successBlock(mockPaymentMethod);
            }] saveCoinbaseAccount:HC_hasEntry(@"code", @"1234") success:[OCMArg isNotNil] failure:[OCMArg any]];

            id mockDelegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];
            coinbase.delegate = mockDelegate;

            id partialCoinbaseMock = [OCMockObject partialMockForObject:coinbase];
            [[[partialCoinbaseMock stub] andReturn:mockClient] client];

            [[mockDelegate expect] appSwitcher:coinbase didCreatePaymentMethod:mockPaymentMethod];

            NSURL *testURL = [NSURL URLWithString:@"com.example.app.payments://x-callback-url/vzero/auth/coinbase/redirect?code=1234"];
            [coinbase handleReturnURL:testURL];

            [mockDelegate verifyWithDelay:10];
        });

        it(@"returns the error returned by coinbase", ^{
            id mockClientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[mockClientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[mockClientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[mockClientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[mockClientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];
            id mockClient = [OCMockObject mockForClass:[BTClient class]];
            [[[mockClient stub] andReturn:mockClientToken] clientToken];
            id mockDelegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];

            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];
            coinbase.delegate = mockDelegate;

            [[mockDelegate expect] appSwitcher:coinbase
                              didFailWithError:HC_allOf(
                                                        HC_hasProperty(@"domain", CoinbaseErrorDomain),
                                                        HC_hasProperty(@"code", HC_equalToInteger(CoinbaseOAuthError)),
                                                        HC_hasProperty(@"localizedDescription", @"This is a test error"),
                                                        nil)];

            NSURL *testURL = [NSURL URLWithString:@"com.example.app.payments://x-callback-url/vzero/auth/coinbase/redirect?error_description=This%20is%20a%20test%20error"];
            [coinbase handleReturnURL:testURL];

            [mockDelegate verifyWithDelay:10];
        });

        it(@"returns the error returned by BTClient when tokenization fails", ^{
            id mockClientToken = [OCMockObject mockForClass:[BTClientToken class]];
            [[[mockClientToken stub] andReturnValue:@(YES)] coinbaseEnabled];
            [[[mockClientToken stub] andReturn:@"test-coinbase-scopes"] coinbaseScope];
            [[[mockClientToken stub] andReturn:@"test-coinbase-client-id"] coinbaseClientId];
            [[[mockClientToken stub] andReturn:@"coinbase-merchant-account@test.example.com"] coinbaseMerchantAccount];
            id mockClient = [OCMockObject mockForClass:[BTClient class]];
            [[[mockClient stub] andReturn:mockClientToken] clientToken];
            NSError *mockError = [OCMockObject mockForClass:[NSError class]];

            [[[mockClient stub] andDo:^(NSInvocation *invocation){
                BTClientFailureBlock failureBlock = [invocation getArgumentAtIndexAsObject:4];
                failureBlock(mockError);
            }] saveCoinbaseAccount:HC_hasEntry(@"code", @"1234") success:[OCMArg isNotNil] failure:[OCMArg any]];
            
            id mockDelegate = [OCMockObject mockForProtocol:@protocol(BTAppSwitchingDelegate)];
            
            BTCoinbase *coinbase = [[BTCoinbase alloc] init];
            [coinbase setReturnURLScheme:@"com.example.app.payments"];
            coinbase.delegate = mockDelegate;
            
            id partialCoinbaseMock = [OCMockObject partialMockForObject:coinbase];
            [[[partialCoinbaseMock stub] andReturn:mockClient] client];
            
            [[mockDelegate expect] appSwitcher:coinbase didFailWithError:mockError];
            
            NSURL *testURL = [NSURL URLWithString:@"com.example.app.payments://x-callback-url/vzero/auth/coinbase/redirect?code=1234"];
            [coinbase handleReturnURL:testURL];
            
            [mockDelegate verifyWithDelay:10];
        });
    });
});

SpecEnd