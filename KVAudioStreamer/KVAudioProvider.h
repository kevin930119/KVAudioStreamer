//
//  KVAudioProvider.h
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/8.
//  Copyright © 2018年 kv. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KVAudioFile.h"

@protocol KVAudioProviderDelegate <NSObject>

/**
 本地流以及网络流都是通过这个回调进行数据获取

 @param data 二进制数据
 */
- (void)audioProviderReceiveData:(NSData*)data;

- (BOOL)audioProviderFileCacheFinishWithDir:(NSString*)dir filename:(NSString*)filename cachepath:(NSString*)cachepath;

/**
 获取数据出错

 @param errorType 错误类型
 @param msg 错误信息
 @param error 如果是网络请求出错，那么将会返回网络请求的错误
 */
- (void)audioProviderDidFailWithErrorType:(KVAudioStreamerErrorType)errorType msg:(NSString*)msg error:(NSError*)error;

@end

@interface KVAudioProvider : NSObject

@property (nonatomic, weak) id <KVAudioProviderDelegate> delegate;
@property (nonatomic, weak) KVAudioFile * file;
@property (nonatomic, assign) long long currentFileLocation;
@property (nonatomic, assign) BOOL cacheEnable;

+ (instancetype)initWithAudioFile:(KVAudioFile*)file delegate:(id<KVAudioProviderDelegate>)delegate;

- (KVAudioProviderReponse)getDataWithOffset:(long long)offset length:(long long)length;

- (void)resetDataRequest;

@end
