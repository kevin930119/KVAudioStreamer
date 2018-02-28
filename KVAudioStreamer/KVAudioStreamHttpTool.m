//
//  KVAudioStreamHttpTool.m
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/8.
//  Copyright © 2018年 kv. All rights reserved.
//

#import "KVAudioStreamHttpTool.h"

@interface KVAudioStreamHttpTool () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSession * urlSession;

@end

@implementation KVAudioStreamHttpTool

+ (instancetype)shareTool {
    static KVAudioStreamHttpTool * kvaudiostreamhttptool = nil;
    static dispatch_once_t kvaudiostreamhttptooltoken;
    dispatch_once(&kvaudiostreamhttptooltoken, ^{
        kvaudiostreamhttptool = [[KVAudioStreamHttpTool alloc] init];
    });
    return kvaudiostreamhttptool;
}

- (instancetype)init {
    if (self = [super init]) {
        NSURLSessionConfiguration * config = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.urlSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (NSURLSessionTask*)downloadURL:(NSURL *)url offset:(long long)offset {
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    if (offset) {
        [request setValue:[NSString stringWithFormat:@"bytes=%lld-", offset] forHTTPHeaderField:@"Range"];
    }
    NSURLSessionDataTask * task = [self.urlSession dataTaskWithRequest:request];
    [task resume];
    return task;
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    completionHandler(NSURLSessionResponseAllow);
    NSHTTPURLResponse * res = (NSHTTPURLResponse*)response;
    if ([self.delegate respondsToSelector:@selector(receiveHttpHeader:)]) {
        [self.delegate receiveHttpHeader:res.allHeaderFields];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    if ([self.delegate respondsToSelector:@selector(receiveHttpData:)]) {
        [self.delegate receiveHttpData:data];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    if ([self.delegate respondsToSelector:@selector(didCompleteWithHttpError:)]) {
        [self.delegate didCompleteWithHttpError:error];
    }
}

@end
