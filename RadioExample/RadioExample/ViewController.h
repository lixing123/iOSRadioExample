//
//  ViewController.h
//  RadioExample
//
//  Created by 李 行 on 15/4/11.
//  Copyright (c) 2015年 lixing123.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ViewController : UIViewController<NSURLConnectionDataDelegate>

@property(nonatomic,retain)NSURLConnection* connection;

@end

