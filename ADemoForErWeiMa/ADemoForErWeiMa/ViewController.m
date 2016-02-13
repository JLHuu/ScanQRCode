//
//  ViewController.m
//  ADemoForErWeiMa
//
//  Created by hujiele on 16/2/1.
//  Copyright © 2016年 hujiele. All rights reserved.
//

#import "ViewController.h"
// 包含头文件
#import <AVFoundation/AVFoundation.h>

#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width

@interface ViewController ()<AVCaptureMetadataOutputObjectsDelegate>

@end

@implementation ViewController
{
    AVCaptureDevice *_device; // 设备
    AVCaptureDeviceInput *_input; // 设备输入
    AVCaptureMetadataOutput *_output; // 输出
    AVCaptureSession *_session; // 链接
    AVCaptureVideoPreviewLayer *_preview; // 展示
    
    UIImageView *_ScanArea; // 扫描范围框
    UIImageView *_ScanLine; // 扫描线
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self createUI];
    [self initScan];
    [self StartScan];
}
- (void)initScan
{
    // 视频设备
    _device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // torchMode 闪光灯状态，需要先调用lockForConfiguration:
    //    [_device lockForConfiguration:nil];
    //    if ([_device isTorchModeSupported:AVCaptureTorchModeOn]) {
    //        _device.torchMode = AVCaptureTorchModeOn;
    //    }
    
    _input = [AVCaptureDeviceInput deviceInputWithDevice:_device error:nil];
    _output = [[AVCaptureMetadataOutput alloc] init];
    // rectOfInterest AVCaptureMetadataOutput的属性，可以设置扫描区域，范围是rect 0~1，这个范围是相对于设备尺寸来说的，这里也就是相对于AVCaptureVideoPreviewLayer的尺寸来说的。注意：此处有坑,rect的属性是反的(x,y互换，w,h互换)，具体请看http://www.tuicool.com/articles/6jUjmur
    _output.rectOfInterest = CGRectMake(.5-(200/SCREEN_HEIGHT)/2.f,.5-(200/SCREEN_WIDTH)/2.f, 200/SCREEN_HEIGHT ,200/SCREEN_WIDTH);
    // 设置输出代理
    dispatch_queue_t serialqueue = dispatch_queue_create("serialqueue", DISPATCH_QUEUE_SERIAL);
    [_output setMetadataObjectsDelegate:self queue:serialqueue];
    _session = [[AVCaptureSession alloc] init];
    // 提高图片质量，提高识别效率
    _session.sessionPreset = AVCaptureSessionPreset1920x1080;
    if ([_session canAddInput:_input]) {
        [_session addInput:_input];
    }
    if ([_session canAddOutput:_output]) {
        [_session addOutput:_output];
    }
    
    // MetadataObjectTypes的设置一定要在session add output后设置，否者运行会crash
    /*
     二维码扫描用AVMetadataObjectTypeQRCode
     条码扫描用AVMetadataObjectTypeEAN13Code, AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code
     关于同时能扫描二维码和条码的效率问题，请看http://www.cocoachina.com/industry/20140530/8615.html
     */
    //    [_output setMetadataObjectTypes:[NSArray arrayWithObjects:AVMetadataObjectTypeEAN8Code, AVMetadataObjectTypeCode128Code, nil]];
    [_output setMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]];
    _preview = [AVCaptureVideoPreviewLayer layerWithSession:_session];
    // AVCaptureVideoPreviewLayer的尺寸决定输入源在video上的尺寸，如果frame放缩，则video也会相应放缩。
    _preview.frame = self.view.bounds;
    // A string defining how the video is displayed within an AVCaptureVideoPreviewLayer bounds rect.
    // 一个字符串用来定义video怎样在AVCaptureVideoPreviewLayer的尺寸下展示
    _preview.videoGravity = AVLayerVideoGravityResizeAspect;
    [self.view.layer addSublayer:_preview];
    [self.view bringSubviewToFront:_ScanArea];
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}
- (void)createUI
{
    _ScanArea = [[UIImageView alloc] init];
    _ScanArea.bounds = CGRectMake(0, 0, 200, 200);
    _ScanArea.center = self.view.center;
    _ScanArea.image = [UIImage imageNamed:@"scanBg"];
    [self.view addSubview:_ScanArea];
    _ScanLine = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, _ScanArea.bounds.size.width, 15)];
    _ScanLine.image = [UIImage imageNamed:@"scanLine"];
    [_ScanArea addSubview:_ScanLine];
    [self addScanAnimation];
}
// 添加动画
- (void)addScanAnimation
{
    CABasicAnimation *animation = [CABasicAnimation animation];
    animation.duration = 2.5;
    animation.repeatCount = MAXFLOAT;
    animation.keyPath = @"transform.translation";
    animation.byValue = [NSValue valueWithCGPoint:CGPointMake(0,_ScanArea.bounds.size.height-_ScanLine.bounds.size.height)];
    [_ScanLine.layer addAnimation:animation forKey:nil];
    [self pauseLayer:_ScanLine.layer];
  
}
// 开始扫描
- (void)StartScan
{
    if (_session) {
        [self resumeLayer:_ScanLine.layer];
        [_session startRunning];
    }
}
// 停止扫描
- (void)StopScan
{
    if (_session) {
        [self pauseLayer:_ScanLine.layer];
        [_session stopRunning];
    }
}
//暂停动画
-(void)pauseLayer:(CALayer*)layer
{
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
}
//恢复动画
-(void)resumeLayer:(CALayer*)layer
{
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
}
#pragma mark - 设备输出代理

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects.count) { // 有数据
        dispatch_async(dispatch_get_main_queue(), ^{
            [self StopScan];// 有关于UI的操作一定要放在主线程中
        });
        AVMetadataMachineReadableCodeObject *Codeobjc = metadataObjects[0];
        NSString *str = Codeobjc.stringValue;
        UIAlertController *alc = [UIAlertController alertControllerWithTitle:@"扫描结果" message:str preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self StartScan];
        }];
        [alc addAction:action];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:alc animated:YES completion:nil];
        });
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
