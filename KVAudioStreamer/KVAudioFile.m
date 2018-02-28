//
//  KVAudioFile.m
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/5.
//  Copyright © 2018年 kv. All rights reserved.
//

#import "KVAudioFile.h"

@interface KVAudioFile ()

@end

@implementation KVAudioFile

/**
 初始化文件
 
 @param fileurl 文件地址
 @return 如果失败，那么返回nil
 */
+ (instancetype)openFile:(NSString*)fileurl {
    KVAudioFile * file = [[self alloc] init];
    if ([fileurl hasPrefix:@"http"]) {
        file.isNetwork = YES;
    }else if ([fileurl hasPrefix:@"file"]) {
        file.isNetwork = NO;
    }else {
        return nil;
    }
    file.audiourl = fileurl;
    NSArray * fileTypeComs = [fileurl componentsSeparatedByString:@"."];
    if (fileTypeComs.count > 1) {
        NSString * fileType = fileTypeComs.lastObject;
        file.audioFileTypeId = [file hintForFileExtension:fileType];
        file.fileExtension = fileType;
    }else {
        file.audioFileTypeId = 0;
    }
    file.bitRate = 0;
    file.filesize = 0;
    return file;
}

- (AudioFileTypeID)hintForFileExtension:(NSString *)fileExtension
{
    AudioFileTypeID fileTypeHint = kAudioFileAAC_ADTSType;
    if ([fileExtension isEqual:@"mp3"])
    {
        fileTypeHint = kAudioFileMP3Type;
    }
    else if ([fileExtension isEqual:@"wav"])
    {
        fileTypeHint = kAudioFileWAVEType;
    }
    else if ([fileExtension isEqual:@"aifc"])
    {
        fileTypeHint = kAudioFileAIFCType;
    }
    else if ([fileExtension isEqual:@"aiff"])
    {
        fileTypeHint = kAudioFileAIFFType;
    }
    else if ([fileExtension isEqual:@"m4a"])
    {
        fileTypeHint = kAudioFileM4AType;
    }
    else if ([fileExtension isEqual:@"mp4"])
    {
        fileTypeHint = kAudioFileMPEG4Type;
    }
    else if ([fileExtension isEqual:@"caf"])
    {
        fileTypeHint = kAudioFileCAFType;
    }
    else if ([fileExtension isEqual:@"aac"])
    {
        fileTypeHint = kAudioFileAAC_ADTSType;
    }
    return fileTypeHint;
}

@end
