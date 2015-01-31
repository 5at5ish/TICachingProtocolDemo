//
//  TICacheManager.h
//  TICachingProtocolDemo
//
//  Created by Timur Islamgulov on 27/01/15.
//  Copyright (c) 2015 5at5ish. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TICachedItem;

@interface TICacheManager : NSObject

+ (instancetype)sharedCacheManager;

- (TICachedItem *)cachedResponseForRequest:(NSURLRequest *)request;
- (void)storeCachedResponse:(TICachedItem *)cachedResponse forRequest:(NSURLRequest *)request;
- (void)removeAllCachedResponsesForUserAgentIdentifier:(NSString *)identifier;

@end
