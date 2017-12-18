//
//  FZHRVViewController.m
//  FZHRecordVideo
//
//  Created by 1 on 2017/12/18.
//  Copyright © 2017年 fengzhihao. All rights reserved.
//  录制主页面

#import "FZHRVViewController.h"

@interface FZHRVViewController ()
@property (nonatomic, strong) UIButton *dismissButton; //消失按钮
@property (nonatomic, strong) UIButton *recordButton; //录制按钮
@property (nonatomic, strong) UIButton *switchCameraButton; //切换摄像头按钮
@property (nonatomic, strong) UILabel *remindLabel; //提示label
@end

@implementation FZHRVViewController
#pragma mark - LifeCycle
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self setupSubViews];
}
#pragma mark - UI
- (void)setupSubViews {
    [self.view addSubview:self.remindLabel];
    [self.view addSubview:self.dismissButton];
}
#pragma mark - UITableViewDelegate

#pragma mark - CustomDelegate

#pragma mark - EventResponse
- (void)dismissButtonClick {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)switchButtonClick {
    
}
#pragma mark - Network

#pragma mark - GetterAndSetter
- (UIButton *)switchCameraButton {
    if (!_switchCameraButton) {
        _switchCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _switchCameraButton.frame = CGRectMake(300, 50, 50, 50);
        [_switchCameraButton setTitle:@"switch" forState:UIControlStateNormal];
        [_switchCameraButton addTarget:self action:@selector(switchButtonClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _switchCameraButton;
}

- (UIButton *)dismissButton {
    if (!_dismissButton) {
        _dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _dismissButton.frame = CGRectMake(100, 500, 50, 50);
        [_dismissButton setTitle:@"dismiss" forState:UIControlStateNormal];
        [_dismissButton addTarget:self action:@selector(dismissButtonClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _dismissButton;
}

- (UILabel *)remindLabel {
    if (!_remindLabel) {
        _remindLabel = [[UILabel alloc]initWithFrame:CGRectMake(200, 500, 100, 30)];
        _remindLabel.text = @"轻触拍照，按住摄像";
        _remindLabel.textColor = [UIColor whiteColor];
    }
    return _remindLabel;
}

@end
