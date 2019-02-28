//
//  KVAudioConsumer.m
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/9.
//  Copyright © 2018年 kv. All rights reserved.
//

#import "KVAudioConsumer.h"
#import <pthread.h>

void KVAudioFileStream_PropertyListenerProc (void * inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, AudioFileStreamPropertyFlags * ioFlags);

void KVAudioFileStream_PacketsProc (void * inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void * inInputData, AudioStreamPacketDescription    *inPacketDescriptions);

void KVAudioQueueOutputCallback (void * __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer);

void KVAudioQueuePropertyListenerProc (void * __nullable inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID);

@interface KVAudioConsumer (){
@public
    AudioFileStreamID _audiofilestreamid;
    AudioStreamBasicDescription _asbd;  //音频的格式信息
    double _packetDuration;
    AudioQueueBufferRef _audioqueuebufferref[kNumberOfBuffers]; //音频缓存组
    BOOL _inuse[kNumberOfBuffers];  //标记某个音频缓存区是否已入队
    AudioStreamPacketDescription _audiostreampacketdesc[kMaxPacketDesc];    //保存每一帧的信息
    AudioQueueRef _audioQueueRef;   //音频队列

    pthread_mutex_t _mutex; //线程锁，为了解决多线程修改_inuse值的读取冲突
    pthread_cond_t _mutexCond;  //线程条件睡眠，为了解决在将数据放进缓存区，没有空余缓存区时的线程等待的性能优化
    pthread_mutex_t _enQueueMutex;  //入队线程锁
    pthread_mutex_t _audioQueueBufferingMutex;  //网络极差时自动控制播放队列的线程锁
}

@property (atomic, assign) BOOL isPlaying;

@property (atomic, assign) BOOL audioBufferFillComplete; //缓存区数据已经填充完毕
@property (atomic, assign) NSInteger waitingForPlayInAudioQueueBufferCount;   //在音频队列中等待播放的缓存区数
@property (atomic, assign) BOOL waitingForBuffer;    //等待填充缓存区
@property (atomic, assign) NSInteger audioPacketsFilled; //当前buffer填充了多少帧数据
@property (atomic, assign) NSInteger audioDataBytesFilled;   //当前buffer填充的数据大小
@property (atomic, assign) NSInteger audioQueueCurrentBufferIndex;   //缓存区数据的序号

@property (atomic, assign) SInt32 audioTotalBytes;
@property (atomic, assign) SInt32 audioTotalPackets;

@end

@implementation KVAudioConsumer

+ (instancetype)initWithAudioFile:(KVAudioFile*)file delegate:(id<KVAudioConsumerDelegate>)delegate {
    KVAudioConsumer * consumer = [[self alloc] init];
    consumer.file = file;
    consumer.delegate = delegate;
    return consumer;
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&_mutex, NULL);
        pthread_cond_init(&_mutexCond, NULL);
        pthread_mutex_init(&_enQueueMutex, NULL);
        pthread_mutex_init(&_audioQueueBufferingMutex, NULL);
    }
    return self;
}

#pragma mark - 音频控制
- (void)play {
    if (_audioQueueRef != NULL) {
        AudioQueueStart(_audioQueueRef, NULL);
        self.isPause = NO;
        self.isPlaying = YES;
        self.waitingForBuffer = NO;
        if ([self.delegate respondsToSelector:@selector(beginPlay)]) {
            [self.delegate beginPlay];
        }
    }
}

- (void)pause {
    if (_audioQueueRef != NULL) {
        if (!self.waitingForBuffer) {
            AudioQueuePause(_audioQueueRef);
        }
        self.isPause = YES;
        self.isPlaying = NO;
        self.waitingForBuffer = NO;
        if ([self.delegate respondsToSelector:@selector(playPause)]) {
            [self.delegate playPause];
        }
    }
}

- (void)stop {
    [self closeFileStream];
    if ([self.delegate respondsToSelector:@selector(playStop)]) {
        [self.delegate playStop];
    }
    self.isPause = NO;
    self.waitingForBuffer = NO;
}

#pragma mark - 音频属性控制
- (float)getCurrentPlayTime {
    float time = 0;
    if (_audioQueueRef != NULL && self.isPrepare) {
        AudioTimeStamp timeStamp;
        OSStatus status = AudioQueueGetCurrentTime(_audioQueueRef, NULL, &timeStamp, false);
        if (status == noErr) {
            time = timeStamp.mSampleTime / _asbd.mSampleRate;
        }
    }
    return time;
}

- (void)setPlayRate:(float)playRate {
    _playRate = playRate;
    if (_audioQueueRef != NULL) {
        UInt32 enableTimePitchConversion = 1;
        AudioQueueSetProperty (_audioQueueRef, kAudioQueueProperty_EnableTimePitch, &enableTimePitchConversion, sizeof(enableTimePitchConversion));
        AudioQueueSetParameter(_audioQueueRef, kAudioQueueParam_PlayRate, playRate);
    }
}

- (void)prepareWithData:(NSData *)data {
    self.forPrepare = YES;
    [self fillAudioData:data isDiscontinuity:NO];
}

- (void)fillAudioData:(NSData *)data isDiscontinuity:(BOOL)isDiscontinuity {
    if (_audiofilestreamid == NULL) {
        AudioFileStreamOpen((__bridge void*)self, KVAudioFileStream_PropertyListenerProc, KVAudioFileStream_PacketsProc, 0, &_audiofilestreamid);
    }
    //解析数据
    OSStatus status = noErr;
    /*
     kAudioFileStreamParseFlag_Discontinuity
     网上的资料说如果是seek操作的，在解析时需要传入这个，而不是0，但是经过实测，如果是wav文件，那么传入这个值会导致解析出错，所以不用
     */
    status = AudioFileStreamParseBytes(_audiofilestreamid, (UInt32)data.length, [data bytes], 0);
    if (status != noErr) {
        //解析数据出错
        if ([self.delegate respondsToSelector:@selector(audioProviderDidFailWithErrorMsg:)]) {
            [self.delegate audioProviderDidFailWithErrorMsg:@"数据解析出错"];
        }
    }else {
        if (!self.forPrepare && !self.isFinish) {
            //继续获取数据解析
            if (![self fillBufferComplete]) {
                if (self.audioDataBytesFilled) {
                    // 存在未入队的数据
                    BOOL flag = [self getInAudioQueue];
                    if (!flag) {
                        if ([self.delegate respondsToSelector:@selector(audioProviderDidFailWithErrorMsg:)]) {
                            [self.delegate audioProviderDidFailWithErrorMsg:@"音频数据入队失败"];
                        }
                    }
                }
                
                self.audioBufferFillComplete = YES; //数据填充完成标识
            }
        }
    }
}

/**
 重新设置音频队列相关配置
 */
- (void)resetAudioQueueConfig {
    self.audioTotalPackets = 0;
    self.audioTotalBytes = 0;
    self.audioDataBytesFilled = 0;
    self.audioPacketsFilled = 0;
    self.audioQueueCurrentBufferIndex = 0;
    self.audioBufferFillComplete = NO;
    self.waitingForPlayInAudioQueueBufferCount = 0;
    self.isPlaying = NO;
    self.waitingForBuffer = NO;
    self.forPrepare = NO;
}

- (BOOL)fillBufferComplete {
    BOOL flag = YES;
    KVAudioProviderReponse response = [self.delegate wantAudioData];
    if (response == KVAudioProviderReponseDataOff) {
        flag = NO;
    }
    return flag;
}

- (BOOL)getInAudioQueue {
    BOOL flag = NO;
    if (self.isFinish) {
        return NO;
    }
    AudioQueueBufferRef currentBuffer = _audioqueuebufferref[self.audioQueueCurrentBufferIndex];
    if (!currentBuffer) {
        return NO;
    }
    _inuse[self.audioQueueCurrentBufferIndex] = YES;
    self.waitingForPlayInAudioQueueBufferCount++;  //增加待播放的缓存区个数
    OSStatus status = noErr;
    if (self.audioPacketsFilled) {
        status = AudioQueueEnqueueBuffer(_audioQueueRef, currentBuffer, (UInt32)self.audioPacketsFilled, _audiostreampacketdesc);
    }else {
        status = AudioQueueEnqueueBuffer(_audioQueueRef, currentBuffer, 0, NULL);
    }
    if (status == noErr) {
        flag = YES;
    }else {
        _inuse[self.audioQueueCurrentBufferIndex] = NO;
        self.waitingForPlayInAudioQueueBufferCount--;
        return flag;
    }
    
    if (!self.isPlaying && !self.isFinish && !self.isPause) {
        AudioQueueStart(_audioQueueRef, NULL);
        self.isPlaying = YES;
        if ([self.delegate respondsToSelector:@selector(beginPlay)]) {
            [self.delegate beginPlay];
        }
    }else {
        if (self.waitingForBuffer) {
            self.waitingForBuffer = NO;
            pthread_mutex_lock(&_audioQueueBufferingMutex);
            //正在等待填充缓存区
            if ([self.delegate respondsToSelector:@selector(beginPlay)]) {
                [self.delegate beginPlay];
            }
            AudioQueueStart(_audioQueueRef, NULL);
            pthread_mutex_unlock(&_audioQueueBufferingMutex);
        }
    }
    
    self.audioQueueCurrentBufferIndex = (++self.audioQueueCurrentBufferIndex) % kNumberOfBuffers;
    self.audioPacketsFilled = 0;
    self.audioDataBytesFilled = 0;
    return flag;
}

#pragma mark - audiofilestream回调
- (void)audioFileStreamPropertyListener:(AudioFileStreamPropertyID)inPropertyID ioFlags:(AudioFileStreamPropertyFlags*)ioFlags {
    if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        UInt32 ioPropertyDataSize = sizeof(_asbd);
        //获取音频格式信息
        AudioFileStreamGetProperty(_audiofilestreamid, kAudioFileStreamProperty_DataFormat, &ioPropertyDataSize, &_asbd);
        _packetDuration = _asbd.mFramesPerPacket / _asbd.mSampleRate;
        
        self.isPrepare = YES;
        if ([self.delegate respondsToSelector:@selector(prepareAlready)]) {
            [self.delegate prepareAlready];
        }
    }else if (inPropertyID == kAudioFileStreamProperty_FormatList) {
        //获取aac的音频格式
        Boolean outWriteable;
        UInt32 formatListSize;
        OSStatus err = AudioFileStreamGetPropertyInfo(_audiofilestreamid, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
        if (err != noErr) {
            return;
        }
        
        AudioFormatListItem *formatList = malloc(formatListSize);
        err = AudioFileStreamGetProperty(_audiofilestreamid, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
        if (err != noErr) {
            free(formatList);
            return;
        }
        
        for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem)) {
            AudioStreamBasicDescription pasbd = formatList[i].mASBD;
            if (pasbd.mFormatID == kAudioFormatMPEG4AAC_HE ||
                pasbd.mFormatID == kAudioFormatMPEG4AAC_HE_V2) {
                _asbd = pasbd;
                _packetDuration = _asbd.mFramesPerPacket / _asbd.mSampleRate;
                self.isPrepare = YES;
                if ([self.delegate respondsToSelector:@selector(prepareAlready)]) {
                    [self.delegate prepareAlready];
                }
                break;
            }
        }
        free(formatList);
    }
}

- (void)handleStreamPackets:(UInt32)inNumberBytes inNumberPackets:(UInt32)inNumberPackets inInputData:(const void *)inInputData inPacketDescriptions:(AudioStreamPacketDescription    *)inPacketDescriptions {
    @synchronized (self) {
        if (self.isFinish) {
            return;
        }
        if (self.forPrepare) {
            if (!self.isPrepare) {
                if ([self.delegate respondsToSelector:@selector(audioProviderDidFailWithErrorMsg:)]) {
                    [self.delegate audioProviderDidFailWithErrorMsg:@"音频格式错误"];
                }
            }
            return;
        }
        if (!self.isPrepare) {
            if ([self.delegate respondsToSelector:@selector(audioProviderDidFailWithErrorMsg:)]) {
                [self.delegate audioProviderDidFailWithErrorMsg:@"音频格式错误"];
            }
            return;
        }
        if (_audioQueueRef == NULL) {
            [self createQueue];
        }
        self.audioTotalBytes += inNumberBytes;
        self.audioTotalPackets += inNumberPackets;
        if (!self.file.durationComplete) {
            //获取比特率
            UInt32 bitRate = 0;
            UInt32 ioBitRateSize = sizeof(bitRate);
            AudioFileStreamGetProperty(_audiofilestreamid, kAudioFileStreamProperty_BitRate, &ioBitRateSize, &bitRate);
            if (bitRate != 0) {
                self.file.bitRate = bitRate;
            }else {
                self.file.bitRate = 0;
            }
            
            //计算时长
            float duration = self.file.filesize * 8.0 / self.file.bitRate;
            if (isnan(duration) || isinf(duration)) {
                duration = 0;
            }
            if (duration > 0) {
                self.file.duration = duration;
                self.file.durationComplete = YES;
            }
            
            if (!duration) {
                //如果计算不到时长，那么使用以下方式计算
                if (_asbd.mBytesPerFrame) {
                    double durationPerPacket = _asbd.mFramesPerPacket / _asbd.mSampleRate;
                    long frameCount = (long)(self.file.filesize / _asbd.mBytesPerFrame);
                    long packetCount = frameCount / _asbd.mFramesPerPacket;
                    duration = durationPerPacket * packetCount;
                    self.file.durationComplete = YES;
                }else {
                    duration = -1;
                }
            }
            if (duration == -1) {
                double averagePacketByteSize = self.audioTotalBytes / (float)self.audioTotalPackets;
                double durationPerPacket = _asbd.mFramesPerPacket / _asbd.mSampleRate;
                double bitRate_ca = 8.0 * averagePacketByteSize / durationPerPacket;
                duration = self.file.filesize * 8.0 / bitRate_ca;
                if (isnan(duration) || isinf(duration)) {
                    duration = 0;
                }
            }
            self.file.estimateDuration = duration;
        }
        
        if (inNumberPackets && inPacketDescriptions) {
            for (NSInteger i = 0; i < inNumberPackets; i++) {
                SInt64 mStartOffset = inPacketDescriptions[i].mStartOffset;
                UInt32 mDataByteSize = inPacketDescriptions[i].mDataByteSize;
                
                if (mDataByteSize > self.file.singleBufferSize - self.audioDataBytesFilled) {
                    //要填充的数据已经大于当前缓冲区的剩余空间了
                    BOOL flag = [self getInAudioQueue]; //加入播放队列
                    if (!flag) {
                        //报错
                        if ([self.delegate respondsToSelector:@selector(audioProviderDidFailWithErrorMsg:)]) {
                            [self.delegate audioProviderDidFailWithErrorMsg:@"音频数据入队失败"];
                        }
                        return;
                    }
                }
                
                pthread_mutex_lock(&_mutex);
                while (_inuse[self.audioQueueCurrentBufferIndex]) {
                    //线程等待，避免一直调用，造成的性能损耗
                    pthread_cond_wait(&_mutexCond, &_mutex);
                };
                pthread_mutex_unlock(&_mutex);
                if (self.isFinish) {
                    return;
                }
                
                AudioQueueBufferRef currentBuffer = _audioqueuebufferref[self.audioQueueCurrentBufferIndex];
                if (!currentBuffer) {
                    return;
                }
                currentBuffer->mAudioDataByteSize = (UInt32)(self.audioDataBytesFilled + mDataByteSize);
                memcpy(currentBuffer->mAudioData + self.audioDataBytesFilled, inInputData + mStartOffset, mDataByteSize);
                
                _audiostreampacketdesc[self.audioPacketsFilled] = inPacketDescriptions[i];
                _audiostreampacketdesc[self.audioPacketsFilled].mStartOffset = self.audioDataBytesFilled;
                self.audioDataBytesFilled += mDataByteSize;
                self.audioPacketsFilled += 1;
            }
        }else {
            long offset = 0;
            while (inNumberBytes)
            {
                pthread_mutex_lock(&_mutex);
                while (_inuse[self.audioQueueCurrentBufferIndex]) {
                    //线程等待，避免一直调用，造成的性能损耗
                    pthread_cond_wait(&_mutexCond, &_mutex);
                };
                pthread_mutex_unlock(&_mutex);
                
                if (self.isFinish) {
                    return;
                }
                
                long bufSpaceRemaining = self.file.singleBufferSize;
                
                long copySize;
                if (bufSpaceRemaining < inNumberBytes)
                {
                    copySize = bufSpaceRemaining;
                }
                else
                {
                    copySize = inNumberBytes;
                }
                
                AudioQueueBufferRef fillBuf = _audioqueuebufferref[self.audioQueueCurrentBufferIndex];
                if (!fillBuf) {
                    return;
                }
                fillBuf->mAudioDataByteSize = (UInt32)(copySize);
                memcpy((char*)fillBuf->mAudioData, (const char*)(inInputData + offset), copySize);
                
                self.audioDataBytesFilled = copySize;
                self.audioPacketsFilled = 0;
                inNumberBytes -= copySize;
                offset += copySize;
                
                BOOL flag = [self getInAudioQueue]; //加入播放队列
                if (!flag) {
                    //报错
                    if ([self.delegate respondsToSelector:@selector(audioProviderDidFailWithErrorMsg:)]) {
                        [self.delegate audioProviderDidFailWithErrorMsg:@"音频数据入队失败"];
                    }
                }
            }
        }
    }
}

#pragma mark - audioqueue回调
- (void)audioQueuePropertyListener:(AudioQueuePropertyID)inPropertyID {
    
}

- (void)singleAudioQueueBufferPlayComplete:(NSInteger)index {
    if (self.isFinish) {
        return;
    }
    
    self.waitingForPlayInAudioQueueBufferCount--;
    if (self.waitingForPlayInAudioQueueBufferCount < 0) {
        self.waitingForPlayInAudioQueueBufferCount = 0;
    }
    pthread_mutex_lock(&_mutex);
    _inuse[index] = NO;
    pthread_cond_signal(&_mutexCond);
    pthread_mutex_unlock(&_mutex);
    
    if (self.waitingForPlayInAudioQueueBufferCount <= 0) {
        //播放完成了
        if (self.audioBufferFillComplete) {
            // 延迟执行，为了解决某些音频在还未播放完成时系统提前调用了该方法
            [self performSelector:@selector(notifyAudioPlayFinish) withObject:nil afterDelay:2.0];
        }else {
            self.waitingForBuffer = YES;
            pthread_mutex_lock(&_audioQueueBufferingMutex);
            //缓存区全部播放完成，但是数据没有加载完成，等待解析数据
            if ([self.delegate respondsToSelector:@selector(playDone)] && !self.isFinish) {
                [self.delegate playDone];
            }
            AudioQueuePause(_audioQueueRef);
            pthread_mutex_unlock(&_audioQueueBufferingMutex);
        }
    }
}

- (void)notifyAudioPlayFinish {
    //数据全加载完成
    if ([self.delegate respondsToSelector:@selector(playFinish)] && !self.isFinish) {
        [self.delegate playFinish];
    }
    //播放完成，清除资源
    [self resetAudioQueue];
    self.isPause = NO;
    [self closeFileStream];
}

- (void)createQueue {
    //释放之前的音频队列
    [self releaseAudioQueue];
    OSStatus status = AudioQueueNewOutput(&_asbd, KVAudioQueueOutputCallback, (__bridge void*)self, NULL, NULL, 0, &_audioQueueRef);
    if (status == noErr) {
        //添加状态通知
        AudioQueueAddPropertyListener(_audioQueueRef, kAudioQueueProperty_IsRunning, KVAudioQueuePropertyListenerProc, (__bridge void*)self);
        UInt32 enableTimePitchConversion = 1;
        AudioQueueSetProperty (_audioQueueRef, kAudioQueueProperty_EnableTimePitch, &enableTimePitchConversion, sizeof(enableTimePitchConversion));
        AudioQueueSetParameter(_audioQueueRef, kAudioQueueParam_PlayRate, self.playRate);
        for (NSInteger i = 0; i < kNumberOfBuffers; i++) {
            //为每一个缓冲区分配空间
            AudioQueueAllocateBuffer(_audioQueueRef, self.file.singleBufferSize, &_audioqueuebufferref[i]);
        }

        //增加cookie数据
        UInt32 cookieSize;
        Boolean writable;
        OSStatus ignorableError;
        ignorableError = AudioFileStreamGetPropertyInfo(_audiofilestreamid, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable);
        if (ignorableError)
        {
            return;
        }
        
        void* cookieData = calloc(1, cookieSize);
        ignorableError = AudioFileStreamGetProperty(_audiofilestreamid, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
        if (ignorableError)
        {
            return;
        }
        
        ignorableError = AudioQueueSetProperty(_audioQueueRef, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
        free(cookieData);
        if (ignorableError)
        {
            return;
        }
        
    }
}

- (SInt64)getSeekDataBytesWithLocation:(long)location {
    SInt64 outDataByteOffset = 0;
    if (_audiofilestreamid != NULL && location != 0) {
        AudioFileStreamSeekFlags ioFlags;
        double durationPerPacket = _asbd.mFramesPerPacket / _asbd.mSampleRate;
        SInt64 seekToPacket = floor(location / durationPerPacket);
        OSStatus status = AudioFileStreamSeek(_audiofilestreamid, seekToPacket, &outDataByteOffset, &ioFlags);
        if (status == noErr && ioFlags == kAudioFileStreamSeekFlag_OffsetIsEstimated) {
            
        }
    }
    return outDataByteOffset;
}

- (void)resetAudioQueue {
    self.isFinish = YES;
    [self releaseAudioQueue];
    [self resetAudioQueueConfig];
}

/**
 释放音频队列相关的资源
 */
- (void)releaseAudioQueue {
    if (_audioQueueRef != NULL) {
        AudioQueueStop(_audioQueueRef, true);
        //清理资源
        for (NSInteger i = 0; i < kNumberOfBuffers; i++) {
            //清理缓存区的数据
            AudioQueueFreeBuffer(_audioQueueRef, _audioqueuebufferref[i]);
            _audioqueuebufferref[i] = NULL;
            _inuse[i] = NO;
        }
        pthread_mutex_lock(&_mutex);
        pthread_cond_signal(&_mutexCond);
        pthread_mutex_unlock(&_mutex);
        //释放音频队列
        AudioQueueDispose(_audioQueueRef, true);
        _audioQueueRef = NULL;
    }
}

/**
 关闭文件流
 */
- (void)closeFileStream {
    if (_audiofilestreamid != NULL) {
        //关闭文件
        AudioFileStreamClose(_audiofilestreamid);
        _audiofilestreamid = NULL;
    }
}

- (void)dealloc {
    [self releaseAudioQueue];
    [self closeFileStream];
    pthread_cond_destroy(&_mutexCond);
    pthread_mutex_destroy(&_mutex);
    pthread_mutex_destroy(&_enQueueMutex);
    pthread_mutex_destroy(&_audioQueueBufferingMutex);
}

@end

void KVAudioFileStream_PropertyListenerProc (void * inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, AudioFileStreamPropertyFlags * ioFlags) {
    KVAudioConsumer * consumer = (__bridge KVAudioConsumer *)inClientData;
    [consumer audioFileStreamPropertyListener:inPropertyID ioFlags:ioFlags];
}

void KVAudioFileStream_PacketsProc (void * inClientData, UInt32 inNumberBytes, UInt32 inNumberPackets, const void * inInputData, AudioStreamPacketDescription    *inPacketDescriptions) {
    KVAudioConsumer * consumer = (__bridge KVAudioConsumer *)inClientData;
    [consumer handleStreamPackets:inNumberBytes inNumberPackets:inNumberPackets inInputData:inInputData inPacketDescriptions:inPacketDescriptions];
    return;
}

void KVAudioQueueOutputCallback (void * __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    KVAudioConsumer * consumer = (__bridge KVAudioConsumer *)inUserData;
    for (NSInteger i = 0; i < kNumberOfBuffers; i++) {
        if (inBuffer == consumer->_audioqueuebufferref[i]) {
            [consumer singleAudioQueueBufferPlayComplete:i];
            break;
        }
    }
}

void KVAudioQueuePropertyListenerProc (void * __nullable inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    KVAudioConsumer * consumer = (__bridge KVAudioConsumer *)inUserData;
    [consumer audioQueuePropertyListener:inID];
}
