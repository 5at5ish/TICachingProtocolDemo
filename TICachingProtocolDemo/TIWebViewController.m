//
//  TIWebViewController.m
//  TICachingProtocolDemo
//
//  Created by Timur Islamgulov on 27/01/15.
//  Copyright (c) 2015 5at5ish. All rights reserved.
//

#import "TIWebViewController.h"
#import "TICachingProtocolDelegateProxy.h"
#import "TICacheManager.h"
#import "AppDelegate.h"

NSString * const TIWebViewControllerDidFinishLoadNotification = @"TIWebViewControllerDidFinishLoadNotification";
NSString * const TIWebViewControllerDidFailLoadNotification = @"TIWebViewControllerDidFailLoadNotification";

@interface TIWebViewController () <UIWebViewDelegate, TICachingProtocolDelegate>

@property (nonatomic, weak) IBOutlet UIWebView *webView;
@property (nonatomic, weak) IBOutlet UISwitch *cacheSwitch;
@property (nonatomic) NSUInteger requestCount;
@property (nonatomic) BOOL shouldFinalize;
@property (nonatomic) BOOL shouldUseCache;

@end

@implementation TIWebViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [[TICachingProtocolDelegateProxy sharedDelegateProxy] addDelegate:self];

    
    self.webView.suppressesIncrementalRendering = YES;
    
    [self setupUserAgent];
    
    self.requestCount = 0;
    self.cacheSwitch.on = self.shouldUseCache;
    
    AppDelegate *delegate = [self applicationDelegate];
    [delegate addObserver:self forKeyPath:@"cacheModeEnabled" options:NSKeyValueObservingOptionOld context:nil];

    [self reload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dealloc
{
    [[TICachingProtocolDelegateProxy sharedDelegateProxy] removeDelegate:self];
}

- (void)setupUserAgent {
    NSDictionary *dictionary = @{@"UserAgent" : self.userAgentIdentifier};
    [[NSUserDefaults standardUserDefaults] registerDefaults:dictionary];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@""]]];
}

- (AppDelegate *)applicationDelegate {
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    return delegate;
}

- (BOOL)shouldUseCache {
    return [[self applicationDelegate] isCacheModeEnabled];
}

- (IBAction)reload {
    [self.webView loadRequest:[NSURLRequest requestWithURL:self.URL]];
}

- (IBAction)toggleSwitch {
    AppDelegate *delegate = [self applicationDelegate];
    delegate.cacheModeEnabled = !delegate.cacheModeEnabled;
}

- (IBAction)reset {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@""]]];
    if (self.shouldUseCache)
        [[TICacheManager sharedCacheManager] removeAllCachedResponsesForUserAgentIdentifier:self.userAgentIdentifier];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"cacheModeEnabled"]) {
        self.cacheSwitch.on = ![change[NSKeyValueChangeOldKey] boolValue];
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    self.requestCount++;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.requestCount--;
    if ([[[webView.request mainDocumentURL] absoluteString] isEqualToString:[[webView.request URL] absoluteString]] && !self.requestCount) {
        
        if (self.shouldFinalize) {
            [[NSNotificationCenter defaultCenter] postNotificationName:TIWebViewControllerDidFinishLoadNotification object:self];
            self.shouldFinalize = NO;
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    self.requestCount--;
    if (([[[webView.request URL] scheme] isEqualToString:@"http"] ||
         [[[webView.request URL] scheme] isEqualToString:@"https"]) && !self.requestCount) {
        [[NSNotificationCenter defaultCenter] postNotificationName:TIWebViewControllerDidFailLoadNotification object:self];
    }
}

#pragma mark - TICachingProtocolDelegate

- (BOOL)URLProtocol:(TICachingProtocol *)protocol shouldUseCacheForRequest:(NSURLRequest *)request
{
    BOOL shouldUseCache = self.shouldUseCache && [[request valueForHTTPHeaderField:@"User-Agent"] isEqualToString:self.userAgentIdentifier];
    return shouldUseCache;
}

@end
