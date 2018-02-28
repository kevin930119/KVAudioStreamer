//
//  KVAudioConsumer.h
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/9.
//  Copyright © 2018年 kv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KVAudioFile.h"

@protocol KVAudioConsumerDelegate <NSObject>

- (KVAudioProviderReponse)wantAudioData;

- (void)prepareAlready;

- (void)beginPlay;

- (void)playPause;

- (void)playStop;

- (void)playFinish;

/**
 播放完成，没有等待播放的缓存区，而且也没有结束数据解析
 */
- (void)playDone;

- (void)audioProviderDidFailWithErrorMsg:(NSString*)msg;

@end

@interface KVAudioConsumer : NSObject

@property (nonatomic, weak) id <KVAudioConsumerDelegate> delegate;
@property (nonatomic, weak) KVAudioFile * file;
@property (atomic, assign) BOOL isFinish;   //标识音频已经被结束，不再解析数据了
@property (atomic, assign) BOOL isPrepare;  //音频是否准备完成
@property (nonatomic, assign) BOOL isPause; //音频是否处于暂停状态
@property (nonatomic, assign) float playRate;   //播放速率
@property (atomic, assign) BOOL forPrepare;

+ (instancetype)initWithAudioFile:(KVAudioFile*)file delegate:(id<KVAudioConsumerDelegate>)delegate;

#pragma mark - 音频控制
- (void)prepareWithData:(NSData*)data;    //这里主要是提前获取音频格式
- (void)play;
- (void)pause;
- (void)stop;
#pragma mark - 音频属性控制
- (float)getCurrentPlayTime;

#pragma mark - 音频文件解析相关
- (void)fillAudioData:(NSData*)data isDiscontinuity:(BOOL)isDiscontinuity;
- (BOOL)fillBufferComplete;

- (SInt64)getSeekDataBytesWithLocation:(long)location;

- (void)resetAudioQueue;
- (void)releaseAudioQueue;
- (void)closeFileStream;

@end
