//
//  TICacheManager.m
//  TICachingProtocolDemo
//
//  Created by Timur Islamgulov on 27/01/15.
//  Copyright (c) 2015 5at5ish. All rights reserved.
//

#import "TICacheManager.h"
#import "TICachedItem.h"
#import "TIWebViewController.h"

@interface TICacheManager ()
@end

@implementation TICacheManager

+ (instancetype)sharedCacheManager {
    static TICacheManager *sharedCacheManager = nil;
    TICacheManager *manager = nil;
    @synchronized(self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedCacheManager = [[TICacheManager alloc] init];
        });
        manager = sharedCacheManager;
    }
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleNotification:)
                                                     name:TIWebViewControllerDidFinishLoadNotification
                                                   object:nil];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (TICachedItem *)cachedResponseForRequest:(NSURLRequest *)request {
    NSString *cacheDirectory = [[self class] directoryPathForRequest:request];
    NSString *cachePath = [[self class] pathForDirectory:cacheDirectory request:request];
    TICachedItem *cachedItem = [NSKeyedUnarchiver unarchiveObjectWithFile:cachePath];
    if (!cachedItem) {
        // Check temporary directory
        cacheDirectory = [[self class] temporaryDirectoryPathForRequest:request create:NO];
        cachePath = [[self class] pathForDirectory:cacheDirectory request:request];
        cachedItem = [NSKeyedUnarchiver unarchiveObjectWithFile:cachePath];
        if (cachedItem) {
            // Finalize
            NSString *userAgent = [[self class] userAgentForRequest:request];
            [self finalizeCachingForUserAgentIdentifier:userAgent];
        }
    }
    return cachedItem;
}

- (void)storeCachedResponse:(TICachedItem *)cachedResponse forRequest:(NSURLRequest *)request {
    NSString *cacheDirectory = [[self class] temporaryDirectoryPathForRequest:request create:YES];
    NSString *cachePath = [[self class] pathForDirectory:cacheDirectory request:request];
    [NSKeyedArchiver archiveRootObject:cachedResponse toFile:cachePath];
}

- (void)removeAllCachedResponsesForUserAgentIdentifier:(NSString *)identifier {
    NSError *error = nil;
    NSString *path = [[self class] directoryPathForUserAgentIdentifier:identifier];
    [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
}

#pragma mark

+ (NSString *)pathForDirectory:(NSString *)directory request:(NSURLRequest *)request {
    NSString *path = [directory stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"%lx", (unsigned long)[[[request URL] absoluteString] hash]]];
    return path;
}

+ (NSString *)cacheDirectory {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    path = [path stringByAppendingPathComponent:@"Cache"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];
        if (error)
            return nil;
    }
    
    return path;
}

+ (NSString *)directoryPathForRequest:(NSURLRequest *)request {
    NSString *path = nil;
    NSString *userAgent = [self userAgentForRequest:request];
    if ([userAgent length]) {
        path = [self directoryPathForUserAgentIdentifier:userAgent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];
            if (error)
                return nil;
        }
    }
    
    return path;
}

static NSString * const kTemporaryDirectoryPathSuffix = @"-tmp";

+ (NSString *)temporaryDirectoryPathForRequest:(NSURLRequest *)request create:(BOOL)create {
    NSString *path = [[self directoryPathForRequest:request] stringByAppendingString:kTemporaryDirectoryPathSuffix];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path] && create) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];
        if (error)
            return nil;
    }
    
    return path;
}

+ (NSString *)directoryPathForUserAgentIdentifier:(NSString *)identifier {
    NSString *path = [[self cacheDirectory] stringByAppendingPathComponent:identifier];
    return path;
}

+ (NSString *)temporaryDirectoryPathForUserAgentIdentifier:(NSString *)identifier {
    NSString *path = [[self directoryPathForUserAgentIdentifier:identifier] stringByAppendingString:kTemporaryDirectoryPathSuffix];
    return path;
}

#pragma mark

+ (NSString *)userAgentForRequest:(NSURLRequest *)request {
    NSString *userAgent = [request valueForHTTPHeaderField:@"User-Agent"];
    return userAgent;
}

- (void)finalizeCachingForUserAgentIdentifier:(NSString *)identifier {
    // Finalize caching for specified user agent...
    if (!identifier)
        return;

    NSString *temporaryDirectoryPath = [[self class] temporaryDirectoryPathForUserAgentIdentifier:identifier];
    NSError *error = nil;
    NSString *cacheDirectory = [[self class] directoryPathForUserAgentIdentifier:identifier];
    NSArray *contentsOfTemporaryDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:temporaryDirectoryPath error:nil];
    if ([contentsOfTemporaryDirectory count]) {
        for (NSString *path in contentsOfTemporaryDirectory) {
            NSString *destinationPath = [cacheDirectory stringByAppendingPathComponent:path];
            [[NSFileManager defaultManager] removeItemAtPath:destinationPath error:&error];
            [[NSFileManager defaultManager] moveItemAtPath:[temporaryDirectoryPath stringByAppendingPathComponent:path]
                                                    toPath:destinationPath
                                                     error:&error];
        }
        [[NSFileManager defaultManager] removeItemAtPath:temporaryDirectoryPath error:&error];
    }
}

#pragma mark

- (void)handleNotification:(NSNotification *)notification {
    TIWebViewController *vc = (TIWebViewController *)notification.object;
    NSString *userAgent = vc.userAgentIdentifier;

    if ([notification.name isEqualToString:TIWebViewControllerDidFinishLoadNotification]) {
        [self finalizeCachingForUserAgentIdentifier:userAgent];
    } else {
        NSString *temporaryDirectoryPath = [[self class] temporaryDirectoryPathForUserAgentIdentifier:userAgent];
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:temporaryDirectoryPath error:&error];
    }
}

@end
