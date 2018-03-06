# KVAudioStreamer - 基于AudioToolBox的开源音频流媒体播放器
KVAudioStreamer采用AudioToolBox框架开发，使用C接口开发将更容易自主定制，当然，相对的也增加了开发难度。KVAudioStreamer内部代码结构清晰，采用生产者-消费者的设计模式，方便使用及学习，Demo里面包含了后台播放以及锁屏封面控制的解决方案。
***
KVAudioStreamer拥有以下功能：
1.  支持多种音频格式（mp3、flac、wav、**m4a**...）;
2. 支持缓存功能;
3. 支持定点播放；
4. 多倍率播放。
***
**KVAudioStreamer支持多种音频格式**，经测试，目前音频格式中仅ape格式文件无法播放，另外对m4a音频文件只能做到流播放，无法使用seek操作，后续将会研究如何解决（DOUAudioStreamer无法播放m4a文件），如果开发者不需要播放m4a文件，那么KVAudioStreamer会是一个不错的选择。
**支持缓存功能**，针对网络文件，在完整缓存完毕将会通过代理事件通知开发者缓存成功，携带文件路径供开发者下一步操作（注：仅在完整缓存后才会自动缓存，如果播放网络文件时还未缓存成功就使用了seek操作，那么就不算完整缓存，因为内部使用了断点下载，如果seek后便无法保证文件的完整性，如果文件已经完整缓存成功，重复seek不会产生重复的网络请求，帮助用户节省流量）。
**定点播放**也是KVAudioStreamer的一大特色，支持从音频的某个位置开始播放，用于播放位置记忆功能。
**多倍率播放**，这也是音频播放的一个常用功能，建议区间(0,5)，其实2倍速度播放，出来的声音就已经很鬼畜了。

# 用法
    API使用简单，上手快速。
## 1 初始化
```
self.streamer = [[KVAudioStreamer alloc] init];
self.streamer.delegate = self;
self.streamer.cacheEnable = YES;    //开启缓存功能
//设置httpheader，音乐资源在阿里云OSS开启了防盗链，需要在这里设置referer，如果没有防盗链，那么不需要设置
self.streamer.httpHeaders = @{@"Referer" : @"kevinrefer"};
```
## 2 设置音频路径
```
[self.streamer resetAudioURL:self.filepath];  //音频路径需遵从以下规则
```
KVAudioStreamer通过音频路径来进行本地以及网络文件的区分，所以务必遵从该规则：如果是本地文件，需以`file://`开头，网络文件需以`http`开头，如果音频资源是https，开发者可以自行修改http请求文件中的代码，KVAudioStreamer使用`NSURLSession`作为网络请求框架，处理网络请求的代码全部封装在这里，无需改动其他代码：
![网络请求文件](http://upload-images.jianshu.io/upload_images/1711666-85cd94abe17ef6fd.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
## 3 播放控制
***
- 播放
```
[self.streamer play];
```
- 定点播放
```
[self.streamer playAtTime:60];
```
- 暂停
```
[self.streamer pause];
```
- seek
```
[self.streamer seekToTime:60];
```
- 停止
```
[self.streamer stop];
```
- 设置音量
```
self.streamer.volume = 0.5;
```
- 设置倍速
```
self.streamer.playRate = 0.5;
```
***
## 4 代理通知
KVAudioStreamer使用代理事件进行事件通知，总共有六个代理方法。
***
- 播放状态改变通知，将会在这个代理方法里面接收到流媒体播放过程的各种状态变化。
```
- (void)audioStreamer:(KVAudioStreamer*)streamer playStatusChange:(KVAudioStreamerPlayStatus)status;
```
所有的状态，如下所示：
```
typedef NS_ENUM(NSInteger, KVAudioStreamerPlayStatus) {
KVAudioStreamerPlayStatusIdle,  //闲置状态
KVAudioStreamerPlayStatusBuffering, //缓冲中
KVAudioStreamerPlayStatusPlaying,   //播放
KVAudioStreamerPlayStatusPause, //暂停
KVAudioStreamerPlayStatusFinish,  //完成播放
KVAudioStreamerPlayStatusStop  //停止
};
```
- 音频时长改变通知，KVAudioStreamer内部计算时长使用了三种方法，只有一种能够拿到确切的时长，如果获取不到将会使用另外两种方法进行计算，得出的为近似的音频时长。
```
- (void)audioStreamer:(KVAudioStreamer *)streamer durationChange:(float)duration;
```
近似时长通知，注意：该方法有可能调用多次。
```
- (void)audioStreamer:(KVAudioStreamer *)streamer estimateDurationChange:(float)estimateDuration;
```
- 播放进度通知，内部使用定时器监听播放进度。
```
- (void)audioStreamer:(KVAudioStreamer *)streamer playAtTime:(long)location;
```
- 缓存完成通知，如果开启了缓存功能，并且文件完整缓存成功，将会回调这个方法，返回YES，将会删除该缓存文件。
```
- (BOOL)audioStreamer:(KVAudioStreamer *)streamer cacheCompleteWithRelativePath:(NSString*)relativePath cachepath:(NSString*)cachepath；
```
- 错误通知，内部报错将会回调该方法。
```
- (void)audioStreamer:(KVAudioStreamer *)streamer didFailWithErrorType:(KVAudioStreamerErrorType)errorType msg:(NSString*)msg error:(NSError*)error
```
## 5 使用注意事项
由于KVAudioStreamer使用了定时器进行播放时长监听，所以在适当（不使用）的时候手动释放流媒体播放器。
```
- (void)dealloc {
[self.streamer releaseStreamer];    //释放流媒体
self.streamer = nil;
}
```


