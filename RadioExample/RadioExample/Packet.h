//
//  Packet.h
//  RadioExample
//
//  Created by 李 行 on 15/5/26.
//  Copyright (c) 2015年 lixing123.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface Packet : NSObject

@property(nonatomic,retain)NSData* audioData;
@property(nonatomic,assign)AudioStreamPacketDescription packetDescription;

@end
