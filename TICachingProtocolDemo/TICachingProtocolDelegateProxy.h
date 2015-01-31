//
//  TICachingProtocolDelegateProxy.h
//  TICachingProtocolDemo
//
//  Created by Timur Islamgulov on 27/01/15.
//  Copyright (c) 2015 5at5ish. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TICachingProtocol;

@protocol TICachingProtocolDelegate <NSObject>

- (BOOL)URLProtocol:(TICachingProtocol *)protocol shouldUseCacheForRequest:(NSURLRequest *)request;

@end

@interface TICachingProtocolDelegateProxy : NSObject <TICachingProtocolDelegate>

+ (instancetype)sharedDelegateProxy;
- (void)addDelegate:(id<TICachingProtocolDelegate>)delegate;
- (void)removeDelegate:(id<TICachingProtocolDelegate>)delegate;

@end
