//
//  KVAudioProvider.m
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/8.
//  Copyright © 2018年 kv. All rights reserved.
//

#import "KVAudioProvider.h"
#import "NSString+KVURL.h"
#import "KVAudioStreamHttpTool.h"
#import <pthread.h>

@interface KVAudioProvider () <KVAudioStreamHttpToolDelegate>
//local
@property (nonatomic, strong) NSFileHandle * handle;
//net
@property (nonatomic, strong) NSDictionary * headers;   //头部信息

@property (nonatomic, strong) NSURLSessionTask * lastTask;
/**
 网络数据接收完成
 */
@property (atomic, assign) BOOL netDataReceiveComplete;
@property (atomic, assign) BOOL isDownloading;
@property (atomic, assign) BOOL waitingForNetData;
@property (nonatomic, strong) NSMutableData * netData;
@property (nonatomic, assign) long long netDataRequestStart;    //网络请求时从哪里开始

@end

@implementation KVAudioProvider
{
    pthread_mutex_t _dataAppendMutex;
}

+ (instancetype)initWithAudioFile:(KVAudioFile *)file delegate:(id<KVAudioProviderDelegate>)delegate {
    KVAudioProvider * provider = [[self alloc] init];
    provider.file = file;
    provider.delegate = delegate;
    
    if (!file.isNetwork) {
        //本地资源
        NSString * fileurl1 = [file.audiourl stringByReplacingOccurrencesOfString:@"file://" withString:@""];
        provider.handle = [NSFileHandle fileHandleForReadingAtPath:fileurl1];
        provider.currentFileLocation = 0;
        //获取本地文件大小
        NSError * error = nil;
        NSDictionary * att = [[NSFileManager defaultManager] attributesOfItemAtPath:fileurl1 error:&error];
        if (!error) {
            long long filesize = [att[NSFileSize] longLongValue];
            file.filesize = filesize;
        }else {
            file.filesize = 0;
        }
    }
    return provider;
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&_dataAppendMutex, NULL);
    }
    return self;
}

- (KVAudioProviderReponse)getDataWithOffset:(long long)offset length:(long long)length {
    if (!self.file.isNetwork) {
        return [self getLocalDataWithOffset:offset length:length];
    }else {
        return [self getNetDataWithOffset:offset length:length];
    }
}

- (KVAudioProviderReponse)getLocalDataWithOffset:(long long)offset length:(long long)length {
    if (offset >= self.file.filesize) {
        self.currentFileLocation = self.file.filesize;
        return KVAudioProviderReponseDataOff;
    }
    KVAudioProviderReponse response = KVAudioProviderReponseSuccess;
    [self.handle seekToFileOffset:offset];
    
    NSData * data = nil;
    if (offset + length >= self.file.filesize) {
        data = [self.handle readDataToEndOfFile];
    }else {
        data = [self.handle readDataOfLength:length];
    }
    self.currentFileLocation = offset + length;
    if (data) {
        if ([self.delegate respondsToSelector:@selector(audioProviderReceiveData:)]) {
            [self.delegate audioProviderReceiveData:data];
        }
    }else {
        if ([self.delegate respondsToSelector:@selector(audioProviderDidFailWithErrorType:msg:error:)]) {
            [self.delegate audioProviderDidFailWithErrorType:KVAudioStreamerErrorTypeLocalFile msg:@"获取不到本地文件数据" error:nil];
        }
        response = KVAudioProviderReponseFail;
    }
    return response;
}

- (KVAudioProviderReponse)getNetDataWithOffset:(long long)offset length:(long long)length {
    if (self.isDownloading) {
        if (offset >= self.file.filesize) {
            self.currentFileLocation = self.file.filesize;
            return KVAudioProviderReponseDataOff;
        }
    }
    NSString * encodedString = [self.file.audiourl kv_urlEncodedString];
    NSURL * url = [NSURL URLWithString:encodedString];
    if (!url) {
        return KVAudioProviderReponseFail;
    }
    self.currentFileLocation = offset;
    KVAudioProviderReponse response = KVAudioProviderReponseSuccess;
    if (!self.isDownloading) {
        self.isDownloading = YES;
        response = KVAudioProviderReponseWaiting;
        self.netDataRequestStart = offset;
        self.lastTask = [[KVAudioStreamHttpTool shareTool] downloadURL:url offset:offset];
        [KVAudioStreamHttpTool shareTool].delegate = self;
        self.waitingForNetData = YES;
    }else {
        if ((self.netData.length + self.netDataRequestStart) - offset > kAudioFileBufferSize || self.netDataReceiveComplete) {
            pthread_mutex_lock(&_dataAppendMutex);
            NSData * data = [self.netData subdataWithRange:NSMakeRange(offset - self.netDataRequestStart, self.netData.length - (offset - self.netDataRequestStart))];
            self.currentFileLocation = offset + data.length;
            if ([self.delegate respondsToSelector:@selector(audioProviderReceiveData:)]) {
                [self.delegate audioProviderReceiveData:data];
            }
            pthread_mutex_unlock(&_dataAppendMutex);
        }else {
            //等待
            response = KVAudioProviderReponseWaiting;
            self.waitingForNetData = YES;
        }
    }
    return response;
}

- (void)resetDataRequest {
    if (!self.netDataReceiveComplete) {
        //音频文件还没有全部加载完全，需要重新请求数据
        self.isDownloading = NO;
        if (self.lastTask) {
            [self.lastTask cancel];
            self.lastTask = nil;
        }
        self.netData = nil;
    }
    self.currentFileLocation = 0;
    self.waitingForNetData = NO;
}

#pragma mark - http代理
- (void)receiveHttpData:(NSData *)data {
    if (!self.isDownloading) {
        return;
    }
    pthread_mutex_lock(&_dataAppendMutex);
    if (self.netData) {
        [self.netData appendData:data];
    }else {
        self.netData = [NSMutableData dataWithData:data];
    }
    if (self.waitingForNetData) {
        if ((self.netData.length + self.netDataRequestStart) > self.currentFileLocation && ((self.netData.length + self.netDataRequestStart) - self.currentFileLocation > kAudioFileBufferSize)) {
            self.waitingForNetData = NO;
            NSData * data = [self.netData subdataWithRange:NSMakeRange(self.currentFileLocation - self.netDataRequestStart, self.netData.length - (self.currentFileLocation - self.netDataRequestStart))];
            self.currentFileLocation += data.length;
            if ([self.delegate respondsToSelector:@selector(audioProviderReceiveData:)]) {
                [self.delegate audioProviderReceiveData:data];
            }
        }
    }
    pthread_mutex_unlock(&_dataAppendMutex);
}

- (void)receiveHttpHeader:(NSDictionary *)header {
    NSString * Content_Range = header[@"Content-Range"];
    if (Content_Range.length) {
        //是通过seek获取长度的，需要计算文件长度
        NSArray * Content_Ranges = [Content_Range componentsSeparatedByString:@"/"];
        if (Content_Ranges.count == 2) {
            NSString * lengthStr = Content_Ranges.lastObject;
            long long length = [lengthStr longLongValue];
            if (length) {
                self.file.filesize = length;
            }else {
                self.file.filesize = [header[@"Content-Length"] longLongValue];
            }
        }else {
            self.file.filesize = [header[@"Content-Length"] longLongValue];
        }
    }else {
        self.file.filesize = [header[@"Content-Length"] longLongValue];
    }
    self.headers = header;
}

- (void)didCompleteWithHttpError:(NSError *)error {
    if (error) {
        if (error.code != -999 && ![error.localizedDescription isEqualToString:@"cancelled"]) {
            if ([self.delegate respondsToSelector:@selector(audioProviderDidFailWithErrorType:msg:error:)]) {
                [self.delegate audioProviderDidFailWithErrorType:KVAudioStreamerErrorTypeNetwork msg:@"网络请求错误" error:error];
            }
        }
    }else {
        if (self.netData.length && self.netDataRequestStart == 0) {
            self.netDataReceiveComplete = YES;
            if (self.cacheEnable) {
                //允许缓存
                NSString * dir = [self getAudioCacheDir];
                NSString * filename = [self getCacheFileName];
                NSString * cachepath = [dir stringByAppendingPathComponent:filename];
                BOOL flag = YES;
                if ([self.netData writeToFile:cachepath atomically:YES]) {
                    if ([self.delegate respondsToSelector:@selector(audioProviderFileCacheFinishWithDir:filename:cachepath:)]) {
                        flag = [self.delegate audioProviderFileCacheFinishWithDir:KVAudioStreamerFileCacheDirName filename:filename cachepath:cachepath];
                    }
                }
                if (flag) {
                    NSError * error = nil;
                    [[NSFileManager defaultManager] removeItemAtPath:cachepath error:&error];
                }
            }
        }
    }
}

- (NSString*)getAudioCacheDir {
    NSFileManager * fm = [NSFileManager defaultManager];
    NSString * documentPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString * dir = [documentPath stringByAppendingPathComponent:KVAudioStreamerFileCacheDirName];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return dir;
}

- (NSString*)getCacheFileName {
    NSDate * date = [NSDate date];
    NSString * filename = [NSString stringWithFormat:@"%ld.%@", (long)[date timeIntervalSince1970] * 1000, (self.file.fileExtension.length ? self.file.fileExtension : @"tmp")];
    return filename;
}

- (void)dealloc {
    [self.handle closeFile];
    self.handle = nil;
    [self resetDataRequest];
    pthread_mutex_destroy(&_dataAppendMutex);
}

@end
