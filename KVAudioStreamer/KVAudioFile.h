//
//  KVAudioFile.h
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/5.
//  Copyright © 2018年 kv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "KVAudioStreamDef.h"

@interface KVAudioFile : NSObject

/**
 文件路径，网络路径已http开头，本地文件以file开头
 */
@property (nonatomic, copy) NSString * audiourl;

/**
 是否网络音频文件
 */
@property (nonatomic, assign) BOOL isNetwork;

@property (nonatomic, assign) AudioFileTypeID audioFileTypeId;

@property (nonatomic, copy) NSString * fileExtension;
/**
 音频时长
 */
@property (nonatomic, assign) float duration;

/**
 音频近似时长
 */
@property (nonatomic, assign) float estimateDuration;

@property (nonatomic, assign) BOOL durationComplete;

/**
 文件大小，以b为单位
 */
@property (nonatomic, assign) UInt64 filesize;

/**
 音频比特率
 */
@property (nonatomic, assign) UInt32 bitRate;

/**
 单个缓存区的大小
 */
@property (nonatomic, assign) int singleBufferSize;

/**
 最小的数据单位
 某些音频文件需要提前喂给更大的数据才能解析出数据，目前除了m4a文件需要提前知道600K的大小外，其他都是256k，如果在播放音频时出现解析错误，那么可以尝试将这个值改大一点
 */
@property (nonatomic, assign) long minRequestDataBytes;

/**
 初始化文件

 @param fileurl 文件地址
 @return 如果失败，那么返回nil
 */
+ (instancetype)openFile:(NSString*)fileurl;

@end
