//
//  TIWebViewController.h
//  TICachingProtocolDemo
//
//  Created by Timur Islamgulov on 27/01/15.
//  Copyright (c) 2015 5at5ish. All rights reserved.
//

#import <UIKit/UIKit.h>

extern NSString * const TIWebViewControllerDidFinishLoadNotification;
extern NSString * const TIWebViewControllerDidFailLoadNotification;

@interface TIWebViewController : UIViewController

@property (nonatomic, strong) NSString *userAgentIdentifier;
@property (nonatomic, strong) NSURL *URL;


@end
