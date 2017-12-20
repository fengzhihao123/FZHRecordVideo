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
#import "FZHAVPlayer.h"
#import "FZHRecordView.h"
//const
static const NSInteger kHoldSecond = 1; //时间大于这个就是视频，否则为拍照
static const NSInteger kDelayHideLabelTime = 3; //延时隐藏label时间
typedef void (^PropertyChangeBlock)(AVCaptureDevice *captureDevice);
@interface FZHRVViewController ()<
AVCaptureFileOutputRecordingDelegate
>
//UI
@property (nonatomic, strong) UIButton *dismissButton; //消失按钮
@property (nonatomic, strong) FZHRecordView *recordButton; //录制按钮
@property (nonatomic, strong) UIButton *switchCameraButton; //切换摄像头按钮
@property (nonatomic, strong) UILabel *remindLabel; //提示label
@property (nonatomic, strong) UIButton *recordCompleteButton; //录制完成按钮
@property (nonatomic, strong) UIButton *cancelRecordButton; //撤销录制按钮
//Video
@property (nonatomic, strong) AVCaptureSession *session;
//负责从AVCaptureDevice获得输入数据
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;
//视频输出流
@property (nonatomic, strong) AVCaptureMovieFileOutput *captureMovieFileOutput;
//图像预览层，实时显示捕获的图像
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
//后台任务标识
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property (nonatomic ,assign) UIBackgroundTaskIdentifier lastBackgroundTaskIdentifier;
//记录需要保存视频的路径
@property (nonatomic, strong) NSURL *saveVideoUrl;
//是否是摄像 YES 代表是录制  NO 表示拍照
@property (nonatomic, assign) BOOL isVideo;
//记录录制的时间 默认最大60秒
@property (nonatomic, assign) NSInteger seconds;
@property (nonatomic, assign) NSInteger HSeconds;
@property (nonatomic, strong) FZHAVPlayer *player;
@property (nonatomic, strong) UIImage *takeImage;
@property (nonatomic, strong) UIImageView *takeImageView;
@end

@implementation FZHRVViewController
#pragma mark - LifeCycle
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self setupSubViews];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.session stopRunning];
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}
#pragma mark - UI
- (void)setupSubViews {
    [self setupCamera];
    [self setupAllSubViews];
    [self.view addSubview:self.remindLabel];
    [self hideRemindLabel];
    [self.session startRunning];
}

- (void)setupAllSubViews {
    [self.view addSubview:self.dismissButton];
    [self.view addSubview:self.recordButton];
    [self.view addSubview:self.switchCameraButton];
    [self.view addSubview:self.cancelRecordButton];
    [self.view addSubview:self.recordCompleteButton];
    
    [self setupUnRecordViews];
}

- (void)setupUnRecordViews { //未完成录像views
    self.cancelRecordButton.hidden = YES;
    self.recordCompleteButton.hidden = YES;
    
    self.dismissButton.hidden = NO;
    self.switchCameraButton.hidden = NO;
    self.recordButton.hidden = NO;
    
    if (self.isVideo) {
        self.isVideo = NO;
        [self.player stopPlayer];
        self.player.hidden = YES;
    }
    [self.session startRunning];

    if (!self.takeImageView.hidden) {
        self.takeImageView.hidden = YES;
    }
    
    [UIView animateWithDuration:0.25 animations:^{
        [self.view layoutIfNeeded];
    }];
}

- (void)setupRecordCompleteViews {
    self.cancelRecordButton.hidden = NO;
    self.recordCompleteButton.hidden = NO;
    
    self.dismissButton.hidden = YES;
    self.switchCameraButton.hidden = YES;
    self.recordButton.hidden = YES;
    
    if (self.isVideo) {
        
    }
    
    self.lastBackgroundTaskIdentifier = self.backgroundTaskIdentifier;
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    [self.session stopRunning];
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

#pragma mark - CustomDelegate

#pragma mark - EventResponse
- (void)dismissButtonClick {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)switchButtonClick { //切换摄像头
    AVCaptureDevice *currentDevice = [self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition = [currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront) {
        toChangePosition = AVCaptureDevicePositionBack;
    }
    
    toChangeDevice = [self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificaitionToCaptureDevice:toChangeDevice];
    
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput = [[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];

    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.session beginConfiguration];
    //移除原有输入对象
    [self.session removeInput:self.captureDeviceInput];
    //添加新的输入对象
    if ([self.session canAddInput:toChangeDeviceInput]) {
        [self.session addInput:toChangeDeviceInput];
        self.captureDeviceInput = toChangeDeviceInput;
    }
    //提交会话配置
    [self.session commitConfiguration];
}

- (void)recordButtonClick {
//    if (self.recordButton.selected) { //开始录制
//        //根据设备输出获得连接
//        AVCaptureConnection *connection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeAudio];
//        //根据连接取得设备输出的数据
//        if (![self.captureMovieFileOutput isRecording]) {
//            //如果支持多任务则开始多任务
//            if ([[UIDevice currentDevice] isMultitaskingSupported]) {
//                self.backgroundTaskIdentifier = [[UIApplication sharedApplication]beginBackgroundTaskWithExpirationHandler:nil];
//            }
//            if (self.saveVideoUrl) {
//                [[NSFileManager defaultManager] removeItemAtURL:self.saveVideoUrl error:nil];
//            }
//            //预览图层和视频方向保持一致
//            connection.videoOrientation = [self.previewLayer connection].videoOrientation;
//            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingString:@"record.mov"];
//            NSURL *fileURL = [NSURL fileURLWithPath:outputFilePath];
//            [self.captureMovieFileOutput startRecordingToOutputFileURL:fileURL recordingDelegate:self];
//        } else {
//            [self.captureMovieFileOutput stopRecording];
//        }
//    } else { //停止录制
//        if (!self.isVideo) {
//            dispatch_queue_t mainQueue = dispatch_get_main_queue();
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), mainQueue, ^{ //延时3秒
//                [self.captureMovieFileOutput stopRecording];
//            });
//        } else {
//            [self.captureMovieFileOutput stopRecording];
//        }
//    }
}

- (void)recordCompleteButtonClick { //这里进行保存或者发送出去
    if (self.saveVideoUrl) { //视频处理中
        __weak __typeof(&*self)weakSelf = self;
        ALAssetsLibrary *assetsLibrary = [[ALAssetsLibrary alloc]init];
        [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:self.saveVideoUrl completionBlock:^(NSURL *assetURL, NSError *error) {
            NSLog(@"outputUrl:%@",weakSelf.saveVideoUrl);
            [[NSFileManager defaultManager] removeItemAtURL:weakSelf.saveVideoUrl error:nil];
            if (weakSelf.lastBackgroundTaskIdentifier!= UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:weakSelf.lastBackgroundTaskIdentifier];
            }
            if (error) {
                NSLog(@"保存视频到相簿过程中发生错误，错误信息：%@",error.localizedDescription);
            } else {
                if (weakSelf.takeBlock) {
                    weakSelf.takeBlock(assetURL);
                }
                NSLog(@"成功保存视频到相簿.");
                [weakSelf dismissButtonClick];
            }
        }];
    } else {
        //照片
        UIImageWriteToSavedPhotosAlbum(self.takeImage, self, nil, nil);
        if (self.takeBlock) {
            self.takeBlock(self.takeImage);
        }
        [self dismissButtonClick];
    }
}

- (void)cancelRecordButtonClick {
    [self setupUnRecordViews];
}
#pragma mark - AVCaptureFileOutputRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)output didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections { //开始录制
    self.seconds = self.HSeconds;
    [self performSelector:@selector(onStartTranscribe:) withObject:fileURL afterDelay:1.0];
}

- (void)captureOutput:(AVCaptureFileOutput *)output didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray<AVCaptureConnection *> *)connections error:(NSError *)error { //视频录制完成
    [self setupRecordCompleteViews];
    if (self.isVideo) {
        self.saveVideoUrl = outputFileURL;
        if (!self.player) {
            self.player = [[FZHAVPlayer alloc]initWithFrame:self.view.bounds withShowInView:self.view url:outputFileURL];
        } else {
            if (outputFileURL) {
                self.player.videoUrl = outputFileURL;
                self.player.hidden = NO;
            }
        }
    } else {//照片
        self.saveVideoUrl = nil;
        [self videoHandlePhoto:outputFileURL];
    }
}

#pragma mark - PrivateMethod
- (void)videoHandlePhoto:(NSURL *)url {
    AVURLAsset *urlSet = [AVURLAsset assetWithURL:url];
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlSet];
    imageGenerator.appliesPreferredTrackTransform = YES;    // 截图的时候调整到正确的方向
    NSError *error = nil;
    CMTime time = CMTimeMake(0,30);//缩略图创建时间 CMTime是表示电影时间信息的结构体，第一个参数表示是视频第几秒，第二个参数表示每秒帧数.(如果要获取某一秒的第几帧可以使用CMTimeMake方法)
    CMTime actucalTime; //缩略图实际生成的时间
    CGImageRef cgImage = [imageGenerator copyCGImageAtTime:time actualTime:&actucalTime error:&error];
    if (error) {
        NSLog(@"截取视频图片失败:%@",error.localizedDescription);
    }
    CMTimeShow(actucalTime);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    if (image) { //视频截取成功
    } else { //视频截取失败
    }
    
    self.takeImage = image;//[UIImage imageWithCGImage:cgImage];
    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    if (!self.takeImageView) {
        self.takeImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:self.takeImageView];
    }
    self.takeImageView.hidden = NO;
    self.takeImageView.image = self.takeImage;
}

- (void)onStartTranscribe:(NSURL *)fileURL {
    if (self.captureMovieFileOutput.isRecording) {
        self.seconds = self.seconds - 1;
        if (self.seconds > 0) {
            if ((self.HSeconds - self.seconds >= kHoldSecond) && (!self.isVideo)) {
                self.isVideo = YES;
            }
            [self performSelector:@selector(onStartTranscribe:) withObject:fileURL afterDelay:1.0];
        } else {
            if (self.captureMovieFileOutput.isRecording) {
                [self.captureMovieFileOutput stopRecording];
            }
        }
    }
}

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

- (void)removeNotification {
    NSNotificationCenter *notiCenter = [NSNotificationCenter defaultCenter];
    [notiCenter removeObserver:self];
}

- (void)dealloc {
    [self removeNotification];
}
#pragma mark - GetterAndSetter
- (UIButton *)cancelRecordButton {
    if (!_cancelRecordButton) {
        _cancelRecordButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _cancelRecordButton.frame = CGRectMake(200, 300, 50, 50);
        [_cancelRecordButton setTitle:@"cancel" forState:UIControlStateNormal];
        [_cancelRecordButton addTarget:self action:@selector(cancelRecordButtonClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _cancelRecordButton;
}

- (UIButton *)recordCompleteButton {
    if (!_recordCompleteButton) {
        _recordCompleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _recordCompleteButton.frame = CGRectMake(300, 300, 50, 50);
        [_recordCompleteButton setTitle:@"complete" forState:UIControlStateNormal];
        [_recordCompleteButton addTarget:self action:@selector(recordCompleteButtonClick) forControlEvents:UIControlEventTouchUpInside];
    }
    return _recordCompleteButton;
}

- (FZHRecordView *)recordButton {
    if (!_recordButton) {
        _recordButton = [[FZHRecordView alloc]initWithFrame:CGRectMake(200, 400, 60, 60) withMaxRecordNum:10];
    }
    return _recordButton;
}

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
