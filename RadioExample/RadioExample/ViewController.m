//
//  ViewController.m
//  RadioExample
//
//  Created by 李 行 on 15/4/11.
//  Copyright (c) 2015年 lixing123.com. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>

typedef struct MyStreamStruct{
    
}MyStreamStruct;

void MyPropertyListenerCallback( void *inClientData,
                                AudioFileStreamID inAudioFileStream,
                                AudioFileStreamPropertyID inPropertyID,
                                UInt32 *ioFlags ){
    
}

void MyPacketCallback( void *inClientData,
                      UInt32 inNumberBytes,
                      UInt32 inNumberPackets,
                      const void *inInputData,
                      AudioStreamPacketDescription *inPacketDescriptions ){
    
}

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSString* availableRadioURL = @"http://m.hz.qingting.fm/live/4968.m3u8";
    
    MyStreamStruct* myStream;
    AudioFileStreamID audioFileStream;
    
    AudioFileStreamOpen(&myStream,
                        MyPropertyListenerCallback,
                        MyPacketCallback,
                        0,
                        &audioFileStream);
    
    //TODO:Need CFNetwork knowledge.
    //Will get knowledge of this framework before continue.
    
    /*
    AudioFileStreamParseBytes(audioFileStream,
                              <#UInt32 inDataByteSize#>, <#const void *inData#>, <#UInt32 inFlags#>)
     */
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
