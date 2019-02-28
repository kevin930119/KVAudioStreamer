//
//  KVAudioStreamer.m
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/5.
//  Copyright © 2018年 kv. All rights reserved.
//

#import "KVAudioStreamer.h"
#import <AVFoundation/AVFoundation.h>
#import <pthread.h>
#import <MediaPlayer/MediaPlayer.h>

@interface KVAudioStreamer () <KVAudioProviderDelegate, KVAudioConsumerDelegate>
{
    float _volume;
}

@property (atomic, assign) BOOL isDiscontinuity;    //文件流解析时，如果是通过seek操作进行数据解析的需要置为YES
@property (nonatomic, strong) MPVolumeView * volumeView;    //修改系统音量
@property (nonatomic, strong) UISlider * volumeSlider;
@property (nonatomic, strong) NSTimer * playTimeObserveTimer;   //监听播放时长的定时器
@property (nonatomic, assign) long currentSeekTime; //当前seek的位置，为了准确计算播放时长
@property (atomic, assign) BOOL forPrepare;
@property (nonatomic, assign) BOOL notifiedAlreadyPlay; //是否通知了开始播放

@property (nonatomic, assign) long currentPlayLocation;

@end

@implementation KVAudioStreamer
{
    dispatch_queue_t _audioDataParseQueue;  //音频数据解析队列（串行队列）
}

- (instancetype)init {
    if (self = [super init]) {
        self.status = KVAudioStreamerPlayStatusIdle;
        _audioDataParseQueue = dispatch_queue_create("kvaudiostreamerdataparse", NULL);
        self.playRate = 1.0;
        MPVolumeView * volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-100, -100, 100, 40)];
        for (UIView * view in volumeView.subviews) {
            if ([view isKindOfClass:[UISlider class]]) {
                UISlider * slider = (UISlider*)view;
                self.volumeSlider = slider;
                break;
            }
        }
        self.volumeView = volumeView;
        self.currentSeekTime = 0;
    }
    return self;
}

#pragma mark - 音频播放相关
/**
 重设音频地址
 注意：重设音频地址将会停止播放上一个音频
 
 @param audiourl 音频地址，如果为本地音频文件，需要添加file://前缀，如果为网络文件，必须以http开头，支持https
 @return 成功返回YES
 */
- (BOOL)resetAudioURL:(NSString*)audiourl {
    BOOL flag = NO;
    KVAudioFile * file = [KVAudioFile openFile:audiourl];
    //停止播放音频
    [self stop];
    if (file) {
        flag = YES;
        if (self.currentAudioFile) {
            [self.currentAudioFile removeObserver:self forKeyPath:@"duration"];
            [self.currentAudioFile removeObserver:self forKeyPath:@"estimateDuration"];
        }
        self.currentAudioProvider = nil;
        self.currentAudioConsumer = nil;
        self.currentAudioFile = nil;
        self.currentSeekTime = 0;
        self.forPrepare = NO;
        self.notifiedAlreadyPlay = NO;
        self.currentAudioFile = file;
        [self.currentAudioFile addObserver:self forKeyPath:@"duration" options:NSKeyValueObservingOptionNew context:nil];
        [self.currentAudioFile addObserver:self forKeyPath:@"estimateDuration" options:NSKeyValueObservingOptionNew context:nil];
        self.currentAudioUrl = audiourl;
        self.currentAudioProvider = [KVAudioProvider initWithAudioFile:file delegate:self];
        if ([self.httpHeaders isKindOfClass:[NSDictionary class]]) {
            self.currentAudioProvider.httpHeaders = self.httpHeaders;
        }
        self.currentAudioProvider.cacheEnable = self.cacheEnable;
        self.currentAudioConsumer = [KVAudioConsumer initWithAudioFile:file delegate:self];
        self.currentAudioConsumer.playRate = self.playRate;
        [self notifyDelegateForStatusChange:KVAudioStreamerPlayStatusIdle];
    }
    return flag;
}

/**
 播放音频，如果当前为暂停状态，那么会继续播放
 */
- (void)play {
    if (self.status == KVAudioStreamerPlayStatusBuffering || self.status == KVAudioStreamerPlayStatusPlaying) {
        //缓冲中和播放中无效
        return;
    }
    if (self.status == KVAudioStreamerPlayStatusPause) {
        //是暂停状态
        [self.currentAudioConsumer play];
    }else {
        self.currentSeekTime = 0;
        self.forPrepare = NO;
        self.currentAudioConsumer.isFinish = NO;
        if (self.currentAudioFile.isNetwork && !self.currentAudioProvider.netDataReceiveComplete) {
            //是网络数据并且还未完全加载
            [self notifyDelegateForStatusChange:KVAudioStreamerPlayStatusBuffering];
        }
        //开始获取数据
        [self.currentAudioProvider getDataWithOffset:0 length:self.currentAudioFile.minRequestDataBytes];
    }
}

/**
 在某个位置进行播放
 
 @param location 播放位置，以秒为单位
 */
- (void)playAtTime:(long)location {
    if (self.status == KVAudioStreamerPlayStatusBuffering || self.status == KVAudioStreamerPlayStatusPlaying) {
        //缓冲中和播放中无效
        return;
    }
    
    if (self.status == KVAudioStreamerPlayStatusPause) {
        //是暂停状态
        [self.currentAudioConsumer play];
    }else {
        if (location <= 0) {
            [self play];
            return;
        }
        self.currentSeekTime = location;
        self.currentAudioConsumer.isFinish = NO;
        if (self.currentAudioFile.isNetwork && !self.currentAudioProvider.netDataReceiveComplete) {
            //是网络数据并且还未完全加载
            [self notifyDelegateForStatusChange:KVAudioStreamerPlayStatusBuffering];
        }
        //开始获取数据，这里从头获取数据是为了提前知道音频格式，方便计算seek的位置
        self.forPrepare = YES;
        self.currentAudioProvider.forPrepare = YES; //将忽略缓存，因为已经不可能从头开始加载完整了
        [self.currentAudioProvider getDataWithOffset:0 length:self.currentAudioFile.minRequestDataBytes];
    }
}

/**
 seek到某个位置进行播放
 
 @param location 目标位置，以秒为单位
 */
- (void)seekToTime:(long)location {
    if (self.status != KVAudioStreamerPlayStatusBuffering && self.status != KVAudioStreamerPlayStatusPlaying && self.status != KVAudioStreamerPlayStatusPause && !self.currentAudioConsumer.isPrepare) {
        //只有缓冲中和播放中，暂停中或者消费者（音频流）准备完成才有效
        return;
    }
    [self.currentAudioProvider resetDataRequest];
    [self.currentAudioConsumer resetAudioQueue];
    self.currentSeekTime = location;
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(_audioDataParseQueue, ^{
        //计算seek位置也需要放进串行队列里面，不然文件流解析数据会出错
        SInt64 bytesLocation = [weakSelf.currentAudioConsumer getSeekDataBytesWithLocation:location];
        weakSelf.currentAudioProvider.currentFileLocation = bytesLocation;
        weakSelf.isDiscontinuity = YES;
        if (bytesLocation == 0) {
            weakSelf.currentSeekTime = 0;
        }
        if (weakSelf.currentAudioFile.isNetwork && !weakSelf.currentAudioProvider.netDataReceiveComplete) {
            //是网络数据并且还未完全加载
            [weakSelf notifyDelegateForStatusChange:KVAudioStreamerPlayStatusBuffering];
        }
        [weakSelf.currentAudioProvider getDataWithOffset:bytesLocation length:weakSelf.currentAudioFile.minRequestDataBytes];
    });
}

/**
 暂停播放
 */
- (void)pause {
    if (self.status != KVAudioStreamerPlayStatusPlaying && self.status != KVAudioStreamerPlayStatusBuffering) {
        //如果不是缓冲中或播放中无效
        return;
    }
    self.forPrepare = NO;
    [self.currentAudioConsumer pause];
}

/**
 停止播放
 */
- (void)stop {
    if (self.status == KVAudioStreamerPlayStatusStop || self.status == KVAudioStreamerPlayStatusIdle) {
        return;
    }
    if (self.status != KVAudioStreamerPlayStatusFinish) {
        [self notifyDelegateForStatusChange:KVAudioStreamerPlayStatusStop];
    }
    //停止网络请求数据
    self.forPrepare = NO;
    self.currentSeekTime = 0;
    [self.currentAudioProvider resetDataRequest];
    [self.currentAudioConsumer resetAudioQueue];
    __weak __typeof(&*self)weakSelf = self;
    dispatch_async(_audioDataParseQueue, ^{
        [weakSelf.currentAudioConsumer stop];
    });
}

/**
 释放掉流媒体所有资源
 由于流媒体内部使用了串行队列进行数据解析，当在进行数据解析时会做线程等待的操作，尽管已经对流媒体做了弱引用处理，但是队列的执行需要耗费一些时间，所以会导致延迟释放流媒体，需要开发者手动释放流媒体资源，才能达到即时释放的目的，另外，由于使用了定时器进行播放时长的监听，所以也需要手动释放
 */
- (void)releaseStreamer {
    [self releaseTimer];
    [self stop];
    self.currentAudioProvider = nil;
    self.currentAudioConsumer = nil;
    self.currentAudioUrl = nil;
    self.delegate = nil;
}

#pragma mark - 生产者代理事件
- (void)audioProviderReceiveData:(NSData *)data {
    __weak __typeof(&*self)weakSelf = self;
    if (self.forPrepare) {
        dispatch_async(_audioDataParseQueue, ^{
            [weakSelf.currentAudioConsumer prepareWithData:data];
        });
    }else {
        dispatch_async(_audioDataParseQueue, ^{
            BOOL flag = weakSelf.isDiscontinuity;
            if (weakSelf.isDiscontinuity) {
                weakSelf.currentAudioConsumer.isFinish = NO;
                weakSelf.isDiscontinuity = NO;
            }
            [weakSelf.currentAudioConsumer fillAudioData:data isDiscontinuity:flag];
        });
    }
}

- (BOOL)audioProviderFileCacheFinishWithDir:(NSString *)dir filename:(NSString *)filename cachepath:(NSString *)cachepath {
    BOOL flag = YES;
    if ([self.delegate respondsToSelector:@selector(audioStreamer:cacheCompleteWithRelativePath:cachepath:)]) {
        NSString * relativePath = [dir stringByAppendingPathComponent:filename];
        flag = [self.delegate audioStreamer:self cacheCompleteWithRelativePath:relativePath cachepath:cachepath];
    }
    return flag;
}

- (void)audioProviderReceiveDataProgressWithStart:(UInt64)start length:(UInt64)length {
    if (!self.forPrepare) {
        kv_dispatch_main_async_safe(^{
            if ([self.delegate respondsToSelector:@selector(audioStreamer:loadNetworkDataInRange:fileSize:)]) {
                [self.delegate audioStreamer:self loadNetworkDataInRange:NSMakeRange(start, length) fileSize:self.currentAudioFile.filesize];
            }
        });
    }
}

- (void)audioProviderDidFailWithErrorType:(KVAudioStreamerErrorType)errorType msg:(NSString *)msg error:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(audioStreamer:didFailWithErrorType:msg:error:)]) {
        [self.delegate audioStreamer:self didFailWithErrorType:errorType msg:msg error:error];
    }
}

#pragma mark - 消费者代理事件
- (float)playLocation {
    return (float)self.currentPlayLocation;
}

- (KVAudioProviderReponse)wantAudioData {
    return [self.currentAudioProvider getDataWithOffset:self.currentAudioProvider.currentFileLocation length:self.currentAudioFile.minRequestDataBytes];
}

- (void)prepareAlready {
    if (self.forPrepare && self.currentSeekTime) {
        //是需要准备的
        [self seekToTime:self.currentSeekTime];
        self.forPrepare = NO;
    }
}

- (void)beginPlay {
    [self performSelectorOnMainThread:@selector(resetTimer) withObject:nil waitUntilDone:YES];
    [self notifyDelegateForStatusChange:KVAudioStreamerPlayStatusPlaying];
}

- (void)playPause {
    [self performSelectorOnMainThread:@selector(releaseTimer) withObject:nil waitUntilDone:YES];
    [self notifyDelegateForStatusChange:KVAudioStreamerPlayStatusPause];
}

- (void)playStop {
    [self performSelectorOnMainThread:@selector(releaseTimer) withObject:nil waitUntilDone:YES];
}

- (void)playFinish {
    [self performSelectorOnMainThread:@selector(releaseTimer) withObject:nil waitUntilDone:YES];
    [self notifyDelegateForStatusChange:KVAudioStreamerPlayStatusFinish];
}

- (void)playDone {
    [self performSelectorOnMainThread:@selector(releaseTimer) withObject:nil waitUntilDone:YES];
    if (self.currentAudioFile.isNetwork && !self.currentAudioProvider.netDataReceiveComplete) {
        [self notifyDelegateForStatusChange:KVAudioStreamerPlayStatusBuffering];
    }
}

- (void)audioProviderDidFailWithErrorMsg:(NSString *)msg {
    kv_dispatch_main_async_safe(^{
        if ([self.delegate respondsToSelector:@selector(audioStreamer:didFailWithErrorType:msg:error:)]) {
            [self.delegate audioStreamer:self didFailWithErrorType:KVAudioStreamerErrorTypeDecode msg:msg error:nil];
        }
    });
}

#pragma mark - 数据解析
/**
 解析本地音频数据
 @return 判断是否可以解析到数据
 */
- (BOOL)parseLocalFileData {
    return [self.currentAudioProvider getDataWithOffset:self.currentAudioProvider.currentFileLocation length:self.currentAudioFile.minRequestDataBytes];
}

#pragma mark - 其他

/**
 获取当前音量
 
 @return 音量
 */
- (float)volume {
    return [[AVAudioSession sharedInstance] outputVolume];
}

/**
 设置播放音量
 
 @param volume 音量
 */
- (void)setVolume:(float)volume {
    if (volume < 0) {
        volume = 0;
    }
    if (volume > 1) {
        volume = 1;
    }
    self.volumeSlider.value = volume;
}

/**
 设置播放速率
 
 @param playRate 播放速率，1.0为正常速率
 */
- (void)setPlayRate:(float)playRate {
    if (playRate <= 0) {
        playRate = 1;
    }
    _playRate = playRate;
    self.currentAudioConsumer.playRate = playRate;
    if (self.playTimeObserveTimer) {
        [self resetTimer];
    }
}

/**
 设置音量调节的父视图，如果不设置，调节音量的时候会显示系统的音量视图
 注意：调用这个方法控制台会打印一段警告，暂时不清楚原因，但是并不影响使用。
 
 @param volumeSuperView 父视图
 */
- (void)setVolumeSuperView:(UIView*)volumeSuperView {
    if (volumeSuperView) {
        [self.volumeView removeFromSuperview];
        [volumeSuperView addSubview:self.volumeView];
    }
}

#pragma mark - 定时器操作
- (void)releaseTimer {
    if (self.playTimeObserveTimer) {
        [self.playTimeObserveTimer invalidate];
        self.playTimeObserveTimer = nil;
    }
}

- (void)resetTimer {
    [self releaseTimer];
    self.playTimeObserveTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / self.playRate target:self selector:@selector(playTimeChange) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.playTimeObserveTimer forMode:NSRunLoopCommonModes];
}

- (void)playTimeChange {
    float time = [self.currentAudioConsumer getCurrentPlayTime];
    time = roundf(time);    //四舍五入
    if (self.currentAudioFile.duration > 0) {
        if (time > self.currentAudioFile.duration) {
            time = self.currentAudioFile.duration;
        }
    }
    long playTime = self.currentSeekTime + time;
    self.currentAudioFile.currentPlayDuration = (float)playTime;
    if ([self.delegate respondsToSelector:@selector(audioStreamer:playAtTime:)]) {
        [self.delegate audioStreamer:self playAtTime:playTime];
    }
    self.currentPlayLocation = playTime;
}

#pragma mark - 通知代理事件
/**
 通知播放状态改变
 */
- (void)notifyDelegateForStatusChange:(KVAudioStreamerPlayStatus)status {
    if (self.status == status) {
        return;
    }
    kv_dispatch_main_async_safe(^{
        self.status = status;
        if ([self.delegate respondsToSelector:@selector(audioStreamer: playStatusChange:)]) {
            [self.delegate audioStreamer:self playStatusChange:self.status];
        }
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"duration"]) {
        float duration = [change[@"new"] floatValue];
        if (duration > 0) {
            kv_dispatch_main_async_safe(^{
                if ([self.delegate respondsToSelector:@selector(audioStreamer:durationChange:)]) {
                    [self.delegate audioStreamer:self durationChange:duration];
                }
            });
        }
    }else if ([keyPath isEqualToString:@"estimateDuration"]) {
        float estimateDuration = [change[@"new"] floatValue];
        if (estimateDuration) {
            kv_dispatch_main_async_safe(^{
                if ([self.delegate respondsToSelector:@selector(audioStreamer:estimateDurationChange:)]) {
                    [self.delegate audioStreamer:self estimateDurationChange:estimateDuration];
                }
            });
        }
    }
}

- (void)dealloc {
    if (self.currentAudioFile) {
        [self.currentAudioFile removeObserver:self forKeyPath:@"duration"];
        [self.currentAudioFile removeObserver:self forKeyPath:@"estimateDuration"];
    }
}

@end
