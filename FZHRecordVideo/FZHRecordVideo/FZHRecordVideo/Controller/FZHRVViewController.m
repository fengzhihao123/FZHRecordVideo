//
//  FZHRVViewController.m
//  FZHRecordVideo
//
//  Created by 1 on 2017/12/18.
//  Copyright © 2017年 fengzhihao. All rights reserved.
//  录制主页面
#import "FZHRVViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>
//const
static const NSInteger kHoldSecond = 1; //时间大于这个就是视频，否则为拍照
static const NSInteger kDelayHideLabelTime = 3; //延时隐藏label时间
typedef void (^PropertyChangeBlock)(AVCaptureDevice *captureDevice);
@interface FZHRVViewController ()
//UI
@property (nonatomic, strong) UIButton *dismissButton; //消失按钮
@property (nonatomic, strong) UIButton *recordButton; //录制按钮
@property (nonatomic, strong) UIButton *switchCameraButton; //切换摄像头按钮
@property (nonatomic, strong) UILabel *remindLabel; //提示label
//Video
@property (nonatomic, strong) AVCaptureSession *session;
//负责从AVCaptureDevice获得输入数据
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
//视频输出流
@property (nonatomic, strong) AVCaptureMovieFileOutput *captureMovieFileOutput;
//图像预览层，实时显示捕获的图像
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

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
    [self hideRemindLabel];
}

#pragma mark - AVFoundation
- (void)setupCamera {
    //初始化会话，用来结合输入输出
    self.session = [[AVCaptureSession alloc]init];
    //设置分辨率 (设备支持的最高分辨率)
    if ([self.session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        self.session.sessionPreset = AVCaptureSessionPresetHigh;
    }
    //取得后置摄像头
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    //添加一个音频输入设备
#warning TODO:添加版本判断
    AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    //初始化输入设备
    NSError *error = nil;
    self.captureDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    //添加音频
    error = nil;
    AVCaptureDeviceInput *audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:audioDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    
    //输出对象 视频输出
    self.captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc]init];
    
    //将输入设备添加到会话
    if ([self.session canAddInput:self.captureDeviceInput]) {
        [self.session addInput:self.captureDeviceInput];
        [self.session addInput:audioCaptureDeviceInput];
        //设置视频防抖
        AVCaptureConnection *connect = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connect isVideoStabilizationSupported]) {
            connect.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematic;
        }
    }
    
    //将输出设备添加到会话 (刚开始 是照片为输出对象)
    if ([self.session canAddOutput:self.captureMovieFileOutput]) {
        [self.session addOutput:self.captureMovieFileOutput];
    }
    
    //创建视频预览层，用于实时展示摄像头状态
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc]initWithSession:self.session];
    self.previewLayer.frame = self.view.bounds;
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill; //填充模式
    [self.view.layer addSublayer:self.previewLayer];
    
    [self addNotificaitionToCaptureDevice:captureDevice];
}

/**
 *  取得指定位置的摄像头
 *
 *  @param position 摄像头位置
 *
 *  @return 摄像头设备
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition)position {
    NSArray *cameraArray = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in cameraArray) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
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

#pragma mark - PrivateMethod
- (void)hideRemindLabel { //隐藏提示label
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDelayHideLabelTime * NSEC_PER_SEC)), mainQueue, ^{ //延时3秒
       [_remindLabel removeFromSuperview];
    });
}


#pragma mark - Notification
/**
 *  给输入设备添加通知
 */
- (void)addNotificaitionToCaptureDevice:(AVCaptureDevice *)captureDevice {
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
    NSNotificationCenter *notiCenter = [NSNotificationCenter defaultCenter];
    //捕获区域发生改变
    [notiCenter addObserver:self selector:@selector(areaChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

/**
 *  改变设备属性的统一操作方法
 *
 *  @param propertyChange 属性改变操作
 */
- (void)changeDeviceProperty:(PropertyChangeBlock)propertyChange {
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        //自动白平衡
        if ([captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [captureDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        //自动根据环境条件开启闪光灯
        if ([captureDevice isFlashModeSupported:AVCaptureFlashModeAuto]) {
            [captureDevice setFlashMode:AVCaptureFlashModeAuto];
        }
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    } else {
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

- (void)areaChange:(NSNotification *)notification { //捕获区域改变
    
}

- (void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice {
    NSNotificationCenter *notiCenter = [NSNotificationCenter defaultCenter];
    [notiCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}

- (void)dealloc {
    
}
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
