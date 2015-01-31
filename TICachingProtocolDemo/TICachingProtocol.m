//
//  TICachingProtocol.m
//  TICachingProtocolDemo
//
//  Created by Timur Islamgulov on 27/01/15.
//  Copyright (c) 2015 5at5ish. All rights reserved.
//

#import "TICachingProtocol.h"
#import "TICachedItem.h"
#import "TICacheManager.h"
#import "TICachingProtocolDelegateProxy.h"
#import "AppDelegate.h"

#define WORKAROUND_MUTABLE_COPY_LEAK 1

#if WORKAROUND_MUTABLE_COPY_LEAK
// required to workaround http://openradar.appspot.com/11596316
@interface NSURLRequest(MutableCopyWorkaround)

- (id)mutableCopyWorkaround;

@end
#endif

static NSString *TICachingProtocolHandlerKey = @"TICachingProtocolHandlerKey";


@interface TICachingProtocol ()
@property(nonatomic, strong) NSURLConnection *connection;
@property(nonatomic, strong) NSMutableData *data;
@property(nonatomic, strong) NSURLResponse *response;

@property(atomic, copy) NSArray *modes;

- (void)appendData:(NSData *)newData;
@end

@implementation TICachingProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    NSString *userAgent = [request valueForHTTPHeaderField:@"User-Agent"];
    
    BOOL canInit = ([[[request URL] scheme] isEqualToString:@"http"] || [[[request URL] scheme] isEqualToString:@"https"]) &&
    ([userAgent isEqualToString:@"iPhone UA1"] || [userAgent isEqualToString:@"iPhone UA2"]) &&
    ![NSURLProtocol propertyForKey:TICachingProtocolHandlerKey inRequest:request];
    
    if (canInit) {
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

- (void)startLoading
{
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (![self shouldUseCache] && ![delegate isCacheModeEnabled]) {
        NSMutableURLRequest *connectionRequest =
#if WORKAROUND_MUTABLE_COPY_LEAK
        [[self request] mutableCopyWorkaround];
#else
        [[self request] mutableCopy];
#endif
        [NSURLProtocol setProperty:@(YES) forKey:TICachingProtocolHandlerKey inRequest:connectionRequest];
        NSURLConnection *connection = [NSURLConnection connectionWithRequest:connectionRequest
                                                                    delegate:self];
        [self setConnection:connection];
    }
    else if ([delegate isCacheModeEnabled]) {
        TICachedItem *cachedItem = [[TICacheManager sharedCacheManager] cachedResponseForRequest:self.request];
        if (cachedItem) {
            NSData *data = cachedItem.data;
            NSURLResponse *response = cachedItem.response;
            NSURLRequest *redirectRequest = cachedItem.redirectRequest;
            if (redirectRequest) {
                [[self client] URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
            } else {
                
                [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                [[self client] URLProtocol:self didLoadData:data];
                [[self client] URLProtocolDidFinishLoading:self];
            }
        }
        else {
            [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil]];
        }
    }
}

- (void)stopLoading
{
    [[self connection] cancel];
}

#pragma mark - NSURLConnectionDelegate

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    if (response != nil) {
        NSMutableURLRequest *redirectableRequest =
#if WORKAROUND_MUTABLE_COPY_LEAK
        [request mutableCopyWorkaround];
#else
        [request mutableCopy];
#endif

        [NSURLProtocol setProperty:nil forKey:TICachingProtocolHandlerKey inRequest:redirectableRequest];
        
        TICachedItem *cachedItem = [TICachedItem new];
        cachedItem.response = response;
        cachedItem.data = self.data;
        cachedItem.redirectRequest = redirectableRequest;
        [[TICacheManager sharedCacheManager] storeCachedResponse:cachedItem forRequest:self.request];
        [[self client] URLProtocol:self wasRedirectedToRequest:redirectableRequest redirectResponse:response];
        return redirectableRequest;
    } else {
        return request;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [[self client] URLProtocol:self didLoadData:data];
    [self appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [[self client] URLProtocol:self didFailWithError:error];
    [self setConnection:nil];
    [self setData:nil];
    [self setResponse:nil];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self setResponse:response];
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    TICachedItem *cachedItem = [TICachedItem new];
    cachedItem.response = self.response;
    cachedItem.data = self.data;
    [[TICacheManager sharedCacheManager] storeCachedResponse:cachedItem forRequest:self.request];
    
    [[self client] URLProtocolDidFinishLoading:self];
        
    self.connection = nil;
    self.data = nil;
    self.response = nil;
}

- (BOOL)shouldUseCache
{
    return [[TICachingProtocolDelegateProxy sharedDelegateProxy] URLProtocol:self shouldUseCacheForRequest:self.request];
}

- (void)appendData:(NSData *)newData
{
    if ([self data] == nil) {
        [self setData:[newData mutableCopy]];
    }
    else {
        [[self data] appendData:newData];
    }
}

@end

#if WORKAROUND_MUTABLE_COPY_LEAK
@implementation NSURLRequest(MutableCopyWorkaround)

- (id)mutableCopyWorkaround {
    NSMutableURLRequest *mutableURLRequest = [[NSMutableURLRequest alloc] initWithURL:[self URL]
                                                                          cachePolicy:[self cachePolicy]
                                                                      timeoutInterval:[self timeoutInterval]];
    [mutableURLRequest setAllHTTPHeaderFields:[self allHTTPHeaderFields]];
    return mutableURLRequest;
}

@end
#endif

