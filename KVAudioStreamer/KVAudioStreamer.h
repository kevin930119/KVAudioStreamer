//
//  KVAudioStreamer.h
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/5.
//  Copyright © 2018年 kv. All rights reserved.
//
//  该开源项目属Kevin（魏佳林）所有
//  请尊重个人劳动成果，转发注明出处。
//  如有使用问题以及建议或者个人交流请联系 673729631@qq.com
//

#import <UIKit/UIKit.h>
#import "KVAudioProvider.h"
#import "KVAudioConsumer.h"

@class KVAudioStreamer;
@protocol KVAudioStreamerDelegate <NSObject>

@optional

/**
 播放状态改变通知

 @param streamer 流媒体
 @param status 状态
 */
- (void)audioStreamer:(KVAudioStreamer*)streamer playStatusChange:(KVAudioStreamerPlayStatus)status;

/**
 音频时长改变通知
 注意：有些音频文件本身的时长并不准确（可能是音频文件本身的原因），如果开发者已经准确知道时长，建议直接使用，不需要使用流媒体内部计算出的时长

 @param streamer 流媒体
 @param duration 时长
 */
- (void)audioStreamer:(KVAudioStreamer *)streamer durationChange:(float)duration;

/**
 播放进度通知

 @param streamer 流媒体
 @param location 当前播放位置，以秒为单位
 */
- (void)audioStreamer:(KVAudioStreamer *)streamer playAtTime:(long)location;

/**
 文件缓存完成通知，流媒体内部不会处理网络路径与本地路径的映射关系，需要开发者自行处理，例如，第一次播放网络音频，在收到缓存完成后，将缓存文件的路径信息（文件夹，文件名都需要保存，方便下次做路径拼接）保存，下次如果继续播放该网络音频，先获取本地路径，通过本地路径进行音频播放

 @param streamer 流媒体
 @param relativePath 缓存文件相对路径，缓存文件默认保存在系统Ducoment文件夹下
 @param cachepath 缓存文件绝对路径
 @return 返回YES，马上删除缓存文件，返回NO不删除，如果需要自行处理缓存文件的路径，需要自己move文件，然后返回YES
 */
- (BOOL)audioStreamer:(KVAudioStreamer *)streamer cacheCompleteWithRelativePath:(NSString*)relativePath cachepath:(NSString*)cachepath;

/**
 错误通知
 
 @param streamer 流媒体
 @param errorType 错误类型
 @param msg 错误消息
 */
- (void)audioStreamer:(KVAudioStreamer *)streamer didFailWithErrorType:(KVAudioStreamerErrorType)errorType msg:(NSString*)msg;

@end

@interface KVAudioStreamer : NSObject

@property (nonatomic, weak) id <KVAudioStreamerDelegate> delegate;

/**
 当前播放状态
 */
@property (atomic, assign) KVAudioStreamerPlayStatus status;

/**
 当前播放的音频路径
 */
@property (nonatomic, copy) NSString * currentAudioUrl;

/**
 当前的音频文件
 */
@property (nonatomic, strong) KVAudioFile * currentAudioFile;

/**
 当前的音频文件数据生产者
 */
@property (nonatomic, strong) KVAudioProvider * currentAudioProvider;

/**
 当前的音频文件数据消费者
 */
@property (nonatomic, strong) KVAudioConsumer * currentAudioConsumer;

/**
 播放速率，默认为1，建议取值范围在0~5之间
 */
@property (nonatomic, assign) float playRate;

/**
 播放音量
 音量调节使用MPVolumeView实现，如果在设置音量时不希望出现系统音量视图，那么需要调用下方setVolumeSuperView:方法将MPVolumeView添加到可视视图上
 */
@property (nonatomic, assign) float volume;

/**
 是否允许缓存，开启后，在播放网络音频获取数据完整后将会自动保存，文件路径通过代理事件通知
 */
@property (nonatomic, assign) BOOL cacheEnable;

#pragma mark - 音频播放相关
/**
 重设音频地址
 注意：重设音频地址将会停止播放上一个音频
 
 @param audiourl 音频地址，如果为本地音频文件，需要添加file://前缀，如果为网络文件，必须以http（https）开头，支持https
 @return 成功返回YES
 */
- (BOOL)resetAudioURL:(NSString*)audiourl;

/**
 播放音频，如果当前为暂停状态，那么会继续播放
 */
- (void)play;

/**
 在某个位置进行播放

 @param location 播放位置，以秒为单位
 */
- (void)playAtTime:(long)location;

/**
 seek到某个位置进行播放

 @param location 目标位置，以秒为单位
 */
- (void)seekToTime:(long)location;

/**
 暂停播放
 */
- (void)pause;

/**
 停止播放
 */
- (void)stop;

/**
 释放掉流媒体所有资源
 由于流媒体内部使用了串行队列进行数据解析，当在进行数据解析时会做线程等待的操作，尽管已经对流媒体做了弱引用处理，但是队列的执行需要耗费一些时间，所以会导致延迟释放流媒体，需要开发者手动释放流媒体资源，才能达到即时释放的目的，另外，由于使用了定时器进行播放时长的监听，所以也需要手动释放
 */
- (void)releaseStreamer;

/**
 设置音量调节的父视图，如果不设置，调节音量的时候会显示系统的音量视图
 注意：调用这个方法控制台会打印一段警告，暂时不清楚原因，但是并不影响使用。

 @param volumeSuperView 父视图
 */
- (void)setVolumeSuperView:(UIView*)volumeSuperView;

@end
