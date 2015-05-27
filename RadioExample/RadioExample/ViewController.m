//
//  ViewController.m
//  RadioExample
//
//  Created by 李 行 on 15/4/11.
//  Copyright (c) 2015年 lixing123.com. All rights reserved.
//

#import "ViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "Packet.h"

#define BUFFER_COUNT 20
#define BUFFER_SIZE  8000

typedef struct MyStreamStruct{
    AudioFileStreamID stream;
    AudioStreamBasicDescription asbd;
    AudioQueueRef queue;
    AudioQueueBufferRef buffers[BUFFER_COUNT];
}MyStreamStruct;

MyStreamStruct myStream;

//Used to store packets
NSMutableArray* packetQueue;
int audioTotalBuffers;
BOOL audioStarted;
BOOL audioQueuePaused;

AudioQueueBufferRef audioFreeBuffers[BUFFER_COUNT];
BOOL isBuffering;

UILabel* label;

static void CheckError(OSStatus error, const char *operation)
{
    if (error == noErr) return;
    char errorString[20];
    // See if it appears to be a 4-char-code
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) &&
        isprint(errorString[3]) && isprint(errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else
        // No, format it as an integer
        sprintf(errorString, "%d", (int)error);
    fprintf(stderr, "Error: %s (%s)\n", operation, errorString);
    exit(1);
}

#pragma mark - AudioQueueCallback

static void handleAudioQueueCallback(AudioQueueRef inAQ, AudioQueueBufferRef buffer){
    //NSLog(@"%s",__func__);
    AudioStreamPacketDescription inPacketDescriptions[512];
    UInt32 inNumberPacketeDescriptions = 0;
    
    //Without this line, the code will encount error
    buffer->mAudioDataByteSize = 0;
    
    @synchronized(packetQueue){
        //While buffer not filled, continue
        while (packetQueue.count>0) {
            Packet* packet = [packetQueue objectAtIndex:0];
            NSData* data = [packet audioData];
            if ([data length]+buffer->mAudioDataByteSize<BUFFER_SIZE) {
                memcpy((char*)buffer->mAudioData+buffer->mAudioDataByteSize,
                       (const char*)[data bytes],
                       [data length]);
                inPacketDescriptions[inNumberPacketeDescriptions] = packet.packetDescription;
                inPacketDescriptions[inNumberPacketeDescriptions].mStartOffset = buffer->mAudioDataByteSize;
                inNumberPacketeDescriptions++;
                buffer->mAudioDataByteSize += [data length];
                [packetQueue removeObjectAtIndex:0];
            }else{
                //NSLog(@"AudioQueueCallback %d bytes, total %d bytes",(int)[data length],buffer->mAudioDataByteSize);
                break;
            }
        }
        
        if (buffer->mAudioDataByteSize>0) {
            //Enqueue buffer to AudioQueue
            CheckError(AudioQueueEnqueueBuffer(inAQ,
                                               buffer,
                                               inNumberPacketeDescriptions,
                                               inPacketDescriptions),
                       "AudioQueueEnqueueBuffer failed");
        }else if (buffer->mAudioDataByteSize==0){
            for (int i=0; i<BUFFER_COUNT; i++) {
                if (!audioFreeBuffers[i]) {
                    //NSLog(@"waiting for data...");
                    audioFreeBuffers[i] = buffer;
                }
            }
            isBuffering = YES;
        }
    }
}

static void myQueueOutputCallback ( void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer ){
    //NSLog(@"%s",__func__);
    handleAudioQueueCallback(inAQ,
                             inBuffer);
}

#pragma mark - AudioFileStream callback

void MyPropertyListenerCallback( void *inClientData,
                                AudioFileStreamID inAudioFileStream,
                                AudioFileStreamPropertyID inPropertyID,
                                UInt32 *ioFlags ){
    //NSLog(@"%s",__func__);
    MyStreamStruct* myStruct = (MyStreamStruct*)inClientData;
    UInt32 size;
    Boolean writable;
    if (inPropertyID==kAudioFileStreamProperty_ReadyToProducePackets) {
        //Get data format
        CheckError(AudioFileStreamGetPropertyInfo(myStruct->stream,
                                                  kAudioFileStreamProperty_DataFormat,
                                                  &size,
                                                  &writable),
                   "AudioFileStreamGetPropertyInfo kAudioFileStreamProperty_DataFormat");
        
        CheckError(AudioFileStreamGetProperty(myStruct->stream,
                                              kAudioFileStreamProperty_DataFormat,
                                              &size,
                                              &myStruct->asbd),
                   "AudioFileStreamGetProperty kAudioFileStreamProperty_DataFormat");
        
        CheckError(AudioQueueNewOutput(&myStruct->asbd,
                                       myQueueOutputCallback,
                                       myStruct,
                                       NULL,
                                       NULL,
                                       0,
                                       &myStruct->queue),
                   "AudioQueueNewOutput failed");
        
        //Allocate buffers
        for (int i=0; i<BUFFER_COUNT; i++) {
            CheckError(AudioQueueAllocateBuffer(myStruct->queue,
                                                BUFFER_SIZE,
                                                &myStruct->buffers[i]),
                       "AudioQueueAllocateBuffer");
        }
        
        //Set magic cookie
        OSStatus result = AudioFileStreamGetPropertyInfo(myStruct->stream,
                                                         kAudioFileStreamProperty_MagicCookieData,
                                                         &size,
                                                         &writable);
        if (result) {
            NSLog(@"AudioFileStreamGetPropertyInfo kAudioFileStreamProperty_MagicCookieData failed");
        }else{
            void* cookies = malloc(size);
            CheckError(AudioFileStreamGetProperty(myStruct->stream,
                                                  kAudioFileStreamProperty_MagicCookieData,
                                                  &size,
                                                  &cookies),
                       "AudioFileStreamGetProperty kAudioFileStreamProperty_MagicCookieData");
            CheckError(AudioQueueSetProperty(myStruct->queue,
                                             kAudioQueueProperty_MagicCookie,
                                             &cookies,
                                             size),
                       "AudioQueueSetProperty kAudioQueueProperty_MagicCookie");
        }
    }
}

static void startAudioQueue(){
    if (audioQueuePaused) {
        NSLog(@"Start Audio Queue");
        AudioQueueStart(myStream.queue,
                        NULL);
        audioQueuePaused = NO;
    }
    
}

static void pauseAudioQueue(){
    if(!audioQueuePaused){
        NSLog(@"Pause Audio Queue");
        AudioQueuePause(myStream.queue);
        audioQueuePaused = YES;
    }
}

void MyPacketCallback( void *inClientData,
                      UInt32 inNumberBytes,
                      UInt32 inNumberPackets,
                      const void *inInputData,
                      AudioStreamPacketDescription *inPacketDescriptions ){
    //Copy data to packetQueues
    MyStreamStruct* myStruct = (MyStreamStruct*)inClientData;
    
    for (int i=0; i<inNumberPackets; i++) {
        AudioStreamPacketDescription aspd = inPacketDescriptions[i];
        Packet* packet= [[Packet alloc] init];
        packet.audioData = [NSData dataWithBytes:inInputData+aspd.mStartOffset
                                          length:aspd.mDataByteSize];
        packet.packetDescription = aspd;
        @synchronized(packetQueue){
            [packetQueue addObject:packet];
        }
        audioTotalBuffers += aspd.mDataByteSize;
        
        if (!audioStarted) {
            label.text = @"Buffering";
        }
    }
    NSLog(@"packet count:%d",(int)packetQueue.count);
    
    //If audio queue not started and total buffers is "large enough",
    //fill the AudioQueueBuffers and start the audio queue
    //We don't start the queue until the total buffer count is large enough in order to avoid most of the suffering of audio data leverage.
    if (!audioStarted && audioTotalBuffers>BUFFER_COUNT*BUFFER_SIZE*3) {
    //if (!audioStarted && audioTotalBuffers>BUFFER_COUNT*BUFFER_SIZE) {
        for (int i=0; i<BUFFER_COUNT; i++) {
            AudioQueueBufferRef buffer = myStruct->buffers[i];
            handleAudioQueueCallback(myStruct->queue,
                                     buffer);
        }
        
        NSLog(@"starting audio queue");
        CheckError(AudioQueueStart(myStruct->queue,
                                   NULL),
                   "AudioQueueStart failed");
        label.text = @"Playing";
        audioStarted = YES;
    }
    
    //TODO:
    //When packetQueue count is small, pause the queue and wait for enough data.
    //NSLog(@"packet count:%d",(int)packetQueue.count);
    /*if (audioStarted) {
        if (packetQueue.count<500) {
            pauseAudioQueue();
        }else{
            startAudioQueue();
        }
    }*/
    
    //Check for free buffers
    @synchronized(packetQueue){
        for (int i=0; i<BUFFER_COUNT; i++) {
            if (audioFreeBuffers[i] && !audioQueuePaused) {
                handleAudioQueueCallback(myStruct->queue,
                                         audioFreeBuffers[i]);
                audioFreeBuffers[i] = nil;
            }
        }
    }
}

@interface ViewController ()

@end

@implementation ViewController

@synthesize connection;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupAudioSession];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, 320, 100)];
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:20.0];
    [self.view addSubview:label];
    
    NSString* availableRadioURLString = @"http://stream.radiojavan.com";
    NSURL* url                        = [NSURL URLWithString:availableRadioURLString];
    NSURLRequest* request             = [NSURLRequest requestWithURL:url
                                                         cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                     timeoutInterval:20.0];
    self.connection = [NSURLConnection connectionWithRequest:request
                                                    delegate:self];
    [self.connection start];
    
    packetQueue = [[NSMutableArray alloc] init];
    
    audioTotalBuffers = 0;
    audioStarted = NO;
    
    AudioFileStreamOpen(&myStream,
                        MyPropertyListenerCallback,
                        MyPacketCallback,
                        0,
                        &myStream.stream);
}

-(void)setupAudioSession{
    AVAudioSession* session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [session setActive:YES error:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - NSURLConnectionDelegate

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    NSLog(@"%s",__func__);
    //Check error
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse* r = (NSHTTPURLResponse*)response;
        NSLog(@"status code:%ld",(long)[r statusCode]);
    }
}

-(void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    const char* bytes = (const char*)[data bytes];
    UInt32 length = (UInt32)[data length];
    AudioFileStreamParseBytes(myStream.stream,
                              length,
                              bytes,
                              0);
}

@end
