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
    NSDictionary * info = self.arr[indexPath.row];
    NSString * path = info[@"path"];
    KVAudioPlayerController * vc = [[KVAudioPlayerController alloc] init];
    vc.filepath = path;
    [self.navigationController pushViewController:vc animated:YES];
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
        NSString * filepath = [[NSBundle mainBundle] pathForResource:@"002-埃及2" ofType:@"mp3"];
        filepath = [NSString stringWithFormat:@"file://%@", filepath];
        NSString * filepath1 = @"http://artfire-file.oss-cn-beijing.aliyuncs.com/002-埃及2.mp3";
        [_arr addObject:@{@"name" : @"播放单个（本地）", @"path" : filepath}];
        [_arr addObject:@{@"name" : @"播放单个（网络）", @"path" : filepath1}];
    }
    return _arr;
}

@end
