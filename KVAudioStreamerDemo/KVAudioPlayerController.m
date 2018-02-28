//
//  KVAudioPlayerController.m
//  KVAudioStreamer
//
//  Created by kevin on 2018/2/27.
//  Copyright © 2018年 kv. All rights reserved.
//

#import "KVAudioPlayerController.h"
#import "KVAudioStreamer.h"
#import "Masonry.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

@interface KVAudioPlayerController () <KVAudioStreamerDelegate>

@property (nonatomic, strong) KVAudioStreamer * streamer;
@property (nonatomic, strong) UIButton * playBtn;
@property (nonatomic, strong) UISlider * slider;
@property (nonatomic, strong) UISlider * volumeSlider;
@property (nonatomic, assign) BOOL sliderDown;

@end

@implementation KVAudioPlayerController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"流媒体播放器";
    self.view.backgroundColor = [UIColor whiteColor];
    // Do any additional setup after loading the view.
    UIButton * playRateBtn = [UIButton new];
    [playRateBtn setTitle:@"播放速率" forState:UIControlStateNormal];
    [playRateBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    playRateBtn.layer.borderColor = [UIColor blackColor].CGColor;
    playRateBtn.layer.borderWidth = 1;
    playRateBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [playRateBtn addTarget:self action:@selector(playRate) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playRateBtn];
    [playRateBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(100, 40));
        make.top.equalTo(self.view).offset(30 + 64);
        make.right.equalTo(self.view).offset(-15);
    }];
    
    UILabel * label = [UILabel new];
    label.text = @"音量";
    label.font = [UIFont systemFontOfSize:14];
    label.textColor = [UIColor blackColor];
    [self.view addSubview:label];
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(15);
        make.centerY.equalTo(playRateBtn);
    }];
    UISlider * volumeSlider = [UISlider new];
    volumeSlider.maximumValue = 1.0;
    [volumeSlider addTarget:self action:@selector(volumeChange:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:volumeSlider];
    [volumeSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.mas_equalTo(30);
        make.left.equalTo(label.mas_right).offset(15);
        make.right.equalTo(playRateBtn.mas_left).offset(-15);
        make.centerY.equalTo(playRateBtn);
    }];
    self.volumeSlider = volumeSlider;
    
    UIButton * playBtn = [UIButton new];
    [playBtn setTitle:@"播放" forState:UIControlStateNormal];
    [playBtn setTitle:@"暂停" forState:UIControlStateSelected];
    [playBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    playBtn.layer.borderColor = [UIColor blackColor].CGColor;
    playBtn.layer.borderWidth = 1;
    playBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [playBtn addTarget:self action:@selector(playBtn:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:playBtn];
    [playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(100, 40));
        make.center.equalTo(self.view);
    }];
    self.playBtn = playBtn;
    
    UIButton * stopBtn = [UIButton new];
    [stopBtn setTitle:@"停止" forState:UIControlStateNormal];
    [stopBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    stopBtn.layer.borderColor = [UIColor blackColor].CGColor;
    stopBtn.layer.borderWidth = 1;
    stopBtn.titleLabel.font = [UIFont systemFontOfSize:14];
    [stopBtn addTarget:self action:@selector(stop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:stopBtn];
    [stopBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(100, 40));
        make.top.equalTo(playBtn.mas_bottom).offset(30);
        make.centerX.equalTo(self.view);
    }];
    
    self.slider = [UISlider new];
    self.slider.enabled = NO;   //先置为NO，如果已经提前知道了音频的时长，那么可以直接设置maximumValue，就不需要禁止了
    //self.slider.maximumValue = 100;
    [self.slider addTarget:self action:@selector(touchup:) forControlEvents:UIControlEventTouchUpInside];
    [self.slider addTarget:self action:@selector(touchup:) forControlEvents:UIControlEventTouchUpOutside];
    [self.slider addTarget:self action:@selector(touchdown:) forControlEvents:UIControlEventTouchDown];
    [self.view addSubview:self.slider];
    [self.slider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.view).offset(-15);
        make.left.mas_equalTo(30);
        make.right.equalTo(self.view).offset(-30);
        make.height.mas_equalTo(30);
    }];
    
    self.streamer = [[KVAudioStreamer alloc] init];
    self.streamer.delegate = self;
    self.streamer.cacheEnable = YES;
    [self.streamer resetAudioURL:self.filepath];
    //[self.streamer setVolumeSuperView:self.view];
    
    volumeSlider.value = self.streamer.volume;
    //监听音量变化
    [[AVAudioSession sharedInstance] addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setActive:YES error:nil];
}

- (void)touchdown:(UISlider*)slider {
    self.sliderDown = YES;
}

- (void)touchup:(UISlider*)slider {
    self.sliderDown = NO;
    [self.streamer seekToTime:slider.value];
}

- (void)volumeChange:(UISlider*)slider {
    self.streamer.volume = slider.value;
}

- (void)playRate {
    UIAlertController * ac = [UIAlertController alertControllerWithTitle:@"播放速率" message:@"修改播放速率" preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction * action = [UIAlertAction actionWithTitle:@"0.5" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.streamer.playRate = 0.5;
    }];
    [ac addAction:action];
    UIAlertAction * action1 = [UIAlertAction actionWithTitle:@"1.0" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.streamer.playRate = 1.0;
    }];
    [ac addAction:action1];
    UIAlertAction * action2 = [UIAlertAction actionWithTitle:@"1.5" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.streamer.playRate = 1.5;
    }];
    [ac addAction:action2];
    UIAlertAction * action3 = [UIAlertAction actionWithTitle:@"2.0" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.streamer.playRate = 2.0;
    }];
    [ac addAction:action3];
    UIAlertAction * action_cancle = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [ac addAction:action_cancle];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)playBtn:(UIButton*)btn {
    if (btn.selected) {
        [self.streamer pause];
    }else {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        [session setActive:YES error:nil];
//        [self.streamer play];
        [self.streamer playAtTime:100];
    }
}

- (void)stop {
    [self.streamer stop];
}

#pragma mark - 代理
- (void)audioStreamer:(KVAudioStreamer *)streamer playStatusChange:(KVAudioStreamerPlayStatus)status {
    switch (status) {
        case KVAudioStreamerPlayStatusBuffering:
            NSLog(@"缓冲中");
            break;
        case KVAudioStreamerPlayStatusStop:
            NSLog(@"主动停止");
        {
            self.playBtn.selected = NO;
        }
            break;
        case KVAudioStreamerPlayStatusPause:
            NSLog(@"播放暂停");
        {
            self.playBtn.selected = NO;
        }
            break;
        case KVAudioStreamerPlayStatusFinish:
            NSLog(@"播放完成");
        {
            self.playBtn.selected = NO;
        }
            break;
        case KVAudioStreamerPlayStatusPlaying:
            NSLog(@"开始播放");
        {
            self.playBtn.selected = YES;
        }
            break;
        case KVAudioStreamerPlayStatusIdle:
            NSLog(@"闲置状态");
        {
            self.playBtn.selected = NO;
        }
            break;
        default:
            break;
    }
}

- (void)audioStreamer:(KVAudioStreamer *)streamer durationChange:(float)duration {
    self.slider.enabled = YES;
    self.slider.maximumValue = duration;
}

- (void)audioStreamer:(KVAudioStreamer *)streamer playAtTime:(long)location {
    if (!self.sliderDown) {
        self.slider.value = location;
    }
}

- (BOOL)audioStreamer:(KVAudioStreamer *)streamer cacheCompleteWithRelativePath:(NSString *)relativePath cachepath:(NSString *)cachepath {
    NSLog(@"缓存文件成功%@", relativePath);
    return YES;
}

- (void)audioStreamer:(KVAudioStreamer *)streamer didFailWithErrorType:(KVAudioStreamerErrorType)errorType msg:(NSString *)msg error:(NSError *)error {
    NSLog(@"%@", msg);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"outputVolume"]) {
        float outputVolume = [change[@"new"] floatValue];
        self.volumeSlider.value = outputVolume;
    }
}

- (void)dealloc {
    [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
    [self.streamer releaseStreamer];    //释放流媒体
}

@end
