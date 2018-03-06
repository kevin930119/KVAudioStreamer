//
//  AppDelegate.h
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/5.
//  Copyright © 2018年 kv. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kNotifyRemoteControlPlay    @"kNotifyRemoteControlPlay" //点击播放
#define kNotifyRemoteControlPause    @"kNotifyRemoteControlPause" //点击暂停
#define kNotifyRemoteControlNext    @"kNotifyRemoteControlNext" //点击下一首
#define kNotifyRemoteControlPrevious    @"kNotifyRemoteControlPrevious" //点击上一首

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;


@end

