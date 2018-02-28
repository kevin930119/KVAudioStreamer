//
//  KVAudioStreamHttpTool.h
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/8.
//  Copyright © 2018年 kv. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol KVAudioStreamHttpToolDelegate <NSObject>

- (void)receiveHttpData:(NSData*)data;
- (void)receiveHttpHeader:(NSDictionary*)header;
- (void)didCompleteWithHttpError:(NSError*)error;

@end

@interface KVAudioStreamHttpTool : NSObject

@property (nonatomic, weak) id <KVAudioStreamHttpToolDelegate> delegate;

+ (instancetype)shareTool;

- (NSURLSessionTask*)downloadURL:(NSURL*)url offset:(long long)offset;

@end
