//
//  KVAudioStreamDef.h
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/8.
//  Copyright © 2018年 kv. All rights reserved.
//

#ifndef KVAudioStreamDef_h
#define KVAudioStreamDef_h

typedef NS_ENUM(NSInteger, KVAudioStreamerPlayStatus) {
    KVAudioStreamerPlayStatusIdle,  //闲置状态
    KVAudioStreamerPlayStatusBuffering, //缓冲中
    KVAudioStreamerPlayStatusPlaying,   //播放
    KVAudioStreamerPlayStatusPause, //暂停
    KVAudioStreamerPlayStatusFinish,  //完成播放
    KVAudioStreamerPlayStatusStop,  //停止
    KVAudioStreamerPlayStatusError //有错误发生
};

typedef NS_ENUM(NSInteger, KVAudioStreamerErrorType) {
    KVAudioStreamerErrorTypeDecode, //解码出错
    KVAudioStreamerErrorTypeLocalFile,  //本地文件出错，一般为路径出错
    KVAudioStreamerErrorTypeNetwork //网络错误
};

typedef NS_ENUM(NSInteger, KVAudioProviderReponse) {
    KVAudioProviderReponseSuccess,  //获取成功
    KVAudioProviderReponseFail, //获取失败
    KVAudioProviderReponseDataOff,  //没有数据了
    KVAudioProviderReponseWaiting   //等待数据
};

#define kNumberOfBuffers 3              //AudioQueueBuffer数量，一般指明为3
#define kAQBufSize 10240           //每个AudioQueueBuffer的大小
#define kAudioFileBufferSize 61440       //文件读取数据的缓冲区大小
#define kMaxPacketDesc 512              //最大的AudioStreamPacketDescription个数

#define KVAudioStreamerFileCacheDirName @"kvaudiostreamercache" //网络音频文件的缓存文件夹

#endif /* KVAudioStreamDef_h */
