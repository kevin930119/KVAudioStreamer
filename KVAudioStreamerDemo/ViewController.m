//
//  ViewController.m
//  KVAudioStreamerDemo
//
//  Created by kevin on 2018/2/28.
//  Copyright © 2018年 kv. All rights reserved.
//

#import "ViewController.h"
#import "Masonry.h"
#import "KVAudioPlayerController.h"

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView * tableView;
@property (nonatomic, strong) NSMutableArray * arr;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.arr.count;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString * cellid = @"cellid";
    UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:cellid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellid];
    }
    NSDictionary * info = self.arr[indexPath.row];
    cell.textLabel.text = info[@"name"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row == self.arr.count - 1) {
        NSDictionary * info = self.arr[indexPath.row];
        NSArray * paths = info[@"paths"];
        KVAudioPlayerController * vc = [[KVAudioPlayerController alloc] init];
        vc.filepaths = paths;
        vc.title = @"列表播放";
        [self.navigationController pushViewController:vc animated:YES];
    }else {
        NSDictionary * info = self.arr[indexPath.row];
        NSString * path = info[@"path"];
        KVAudioPlayerController * vc = [[KVAudioPlayerController alloc] init];
        vc.filepath = path;
        vc.title = info[@"name"];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

#pragma mark - getter
- (UITableView*)tableView {
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.rowHeight = UITableViewAutomaticDimension;
        _tableView.estimatedRowHeight = 50;
        _tableView.delegate = self;
        _tableView.dataSource = self;
    }
    return _tableView;
}

- (NSMutableArray*)arr {
    if (!_arr) {
        _arr = [NSMutableArray array];
        NSString * filepath = [[NSBundle mainBundle] pathForResource:@"陈奕迅 - 无人之境" ofType:@"mp3"];
        filepath = [NSString stringWithFormat:@"file://%@", filepath];
        NSString * filepath1 = @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/%E9%99%88%E5%A5%95%E8%BF%85%20-%20%E6%97%A0%E4%BA%BA%E4%B9%8B%E5%A2%83.mp3";
        NSString * filepath2 = [[NSBundle mainBundle] pathForResource:@"陈奕迅 - 稳稳的幸福" ofType:@"mp3"];
        filepath2 = [NSString stringWithFormat:@"file://%@", filepath2];
        [_arr addObject:@{@"name" : @"无人之境（本地mp3）", @"path" : filepath}];
        [_arr addObject:@{@"name" : @"无人之境（网络mp3）", @"path" : filepath1}];
        [_arr addObject:@{@"name" : @"Beyond - 海阔天空（网络flac）", @"path" : @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/Beyond%20-%20%E6%B5%B7%E9%98%94%E5%A4%A9%E7%A9%BA.flac"}];
        [_arr addObject:@{@"name" : @"张敬轩 - 笑忘书（网络wav）", @"path" : @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/%E5%BC%A0%E6%95%AC%E8%BD%A9%20-%20%E7%AC%91%E5%BF%98%E4%B9%A6.wav"}];
        [_arr addObject:@{@"name" : @"李宇春 - 口音（网络m4a，无法seek）", @"path" : @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/%E6%9D%8E%E5%AE%87%E6%98%A5%20-%20%E5%8F%A3%E9%9F%B3.m4a"}];
        [_arr addObject:@{@"name" : @"列表播放（混合）", @"paths" : @[@{@"name" : @"陈奕迅 - 无人之境（本地mp3）", @"path" : filepath}, @{@"name" : @"陈奕迅 - 四季圈（网络mp3）", @"path" : @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/%E9%99%88%E5%A5%95%E8%BF%85%20-%20%E5%9B%9B%E5%AD%A3%E5%9C%88.mp3"}, @{@"name" : @"陈奕迅 - 稳稳的幸福（本地mp3）", @"path" : filepath2}, @{@"name" : @"陈奕迅 - 无条件（网络mp3）", @"path" : @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/%E9%99%88%E5%A5%95%E8%BF%85%20-%20%E6%97%A0%E6%9D%A1%E4%BB%B6.mp3"}, @{@"name" : @"陈奕迅 - 最佳损友（网络mp3）", @"path" : @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/%E9%99%88%E5%A5%95%E8%BF%85%20-%20%E6%9C%80%E4%BD%B3%E6%8D%9F%E5%8F%8B.mp3"}, @{@"name" : @"李宇春 - 口音（网络m4a）", @"path" : @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/%E6%9D%8E%E5%AE%87%E6%98%A5%20-%20%E5%8F%A3%E9%9F%B3.m4a"}, @{@"name" : @"张敬轩 - 笑忘书（网络wav）", @"path" : @"http://kevinfile.oss-cn-shenzhen.aliyuncs.com/%E5%BC%A0%E6%95%AC%E8%BD%A9%20-%20%E7%AC%91%E5%BF%98%E4%B9%A6.wav"}]}];
    }
    return _arr;
}

@end
