//
//  TICachingProtocolDelegateProxy.m
//  TICachingProtocolDemo
//
//  Created by Timur Islamgulov on 27/01/15.
//  Copyright (c) 2015 5at5ish. All rights reserved.
//

#import "TICachingProtocolDelegateProxy.h"
#import "TICachingProtocol.h"

@interface TIMulticastDelegate : NSObject
- (void)addDelegate:(id)delegate;
- (void)removeDelegate:(id)delegate;
- (void)removeAllDelegates;
@end

@interface TIMulticastDelegate ()
@property (nonatomic, strong) NSMutableArray *delegates;
@end

@implementation TIMulticastDelegate

- (instancetype)init {
    
    self = [super init];
    if (self){
        _delegates = [NSMutableArray array];
    }
    return self;
}

- (void)addDelegate:(id)delegate {
    [self.delegates addObject:delegate];
}

- (void)removeDelegate:(id)delegate {
    [self.delegates removeObject:delegate];
}

- (void)removeAllDelegates {
    [self.delegates removeAllObjects];
}

- (BOOL)respondsToSelector:(SEL)aSelector {
    if ([super respondsToSelector:aSelector])
        return YES;
    
    for (id delegate in _delegates) {
        if ([delegate respondsToSelector:aSelector]) {
            return YES;
        }
    }
    
    return NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
    
    if (!signature) {
        for (id delegate in _delegates) {
            if ([delegate respondsToSelector:aSelector]) {
                return [delegate methodSignatureForSelector:aSelector];
            }
        }
    }
    
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation {
    for (id delegate in _delegates) {
        if ([delegate respondsToSelector:[anInvocation selector]]) {
            [anInvocation invokeWithTarget:delegate];
        }
    }
}

@end



@interface TICachingProtocolDelegateProxy ()
@property (nonatomic, strong) TIMulticastDelegate<TICachingProtocolDelegate> *delegate;
@end

@implementation TICachingProtocolDelegateProxy

+ (instancetype)sharedDelegateProxy {
    static TICachingProtocolDelegateProxy *sharedDelegateProxy = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDelegateProxy = [[TICachingProtocolDelegateProxy alloc] init];
    });
    
    return sharedDelegateProxy;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _delegate = (TIMulticastDelegate<TICachingProtocolDelegate> *)[[TIMulticastDelegate alloc] init];
    }
    
    return self;
}

- (void)dealloc {
    [_delegate removeAllDelegates];
}

- (BOOL)URLProtocol:(TICachingProtocol *)protocol shouldUseCacheForRequest:(NSURLRequest *)request {
    if ([self.delegate.delegates count] && [self.delegate respondsToSelector:@selector(URLProtocol:shouldUseCacheForRequest:)]) {
        return [self.delegate URLProtocol:protocol shouldUseCacheForRequest:request];
    }
    
    return NO;
}

- (void)addDelegate:(id<TICachingProtocolDelegate>)delegate {
    [self.delegate addDelegate:delegate];
}

- (void)removeDelegate:(id<TICachingProtocolDelegate>)delegate {
    [self.delegate removeDelegate:delegate];
}




@end

