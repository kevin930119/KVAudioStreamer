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
 文件大小，以b为单位
 */
@property (nonatomic, assign) UInt64 filesize;

/**
 音频比特率
 */
@property (nonatomic, assign) UInt32 bitRate;

/**
 初始化文件

 @param fileurl 文件地址
 @return 如果失败，那么返回nil
 */
+ (instancetype)openFile:(NSString*)fileurl;

@end
