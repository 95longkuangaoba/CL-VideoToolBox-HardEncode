//
//  ViewController.m
//  CL-VideoToolBox-HardEncode
//
//  Created by 陈龙 on 16/11/18.
//  Copyright © 2016年 陈龙. All rights reserved.
//

#import "ViewController.h"
#import <UIKit/UIKit.h>
@interface ViewController ()
{
    H264HardEncode * h264Encoder;
    AVCaptureSession * captureSession;
    bool startCalled;
    AVCaptureVideoPreviewLayer  * previewLayer;
    NSString * h264file;
    int fd;
    NSFileHandle * fileHandle;
    AVCaptureConnection * connection;
}



@property (weak, nonatomic) IBOutlet UIButton *StartStopButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    h264Encoder = [H264HardEncode alloc];
    [h264Encoder initWithConfiguration];
    startCalled = true;
    
    
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)OnStartStop:(id)sender {
    if (startCalled) {
        [self startCamera];
        startCalled = false;
        [_StartStopButton setTitle:@"Stop" forState:UIControlStateNormal];
    }
    else
    {
        [_StartStopButton setTitle:@"Start" forState:UIControlStateNormal];
        startCalled = true;
        [self stopCamera];
        [h264Encoder End];
    }
    
    
    
}

-(void)startCamera
{
    NSError * deviceError;
    
    AVCaptureDevice * cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    AVCaptureDeviceInput * inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:cameraDevice error:&deviceError];
    AVCaptureVideoDataOutput * outputDevice = [[AVCaptureVideoDataOutput alloc]init];
    
    NSString * key = (NSString *)kCVPixelBufferPixelFormatTypeKey;
    
    NSNumber * val = [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
    NSDictionary * videoSettings = [NSDictionary dictionaryWithObject:val forKey:key];
    outputDevice.videoSettings = videoSettings;
    
    [outputDevice setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    captureSession = [[AVCaptureSession alloc]init];
    
    [captureSession addInput:inputDevice];
    [captureSession addOutput:outputDevice];
    
    [captureSession beginConfiguration];
    
    [captureSession setSessionPreset:[NSString stringWithString:AVCaptureSessionPreset640x480]];
    
    connection = [outputDevice connectionWithMediaType:AVMediaTypeVideo];
    
    [self setRelativeVideoOrientation];
    
    NSNotificationCenter * notify = [NSNotificationCenter defaultCenter];
    
    [notify addObserver:self selector:@selector(statusBarOrientationDidChange:) name:@"StatusBarOrientationDidChange" object:nil];
    
    [captureSession commitConfiguration];
    
    
    previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
    previewLayer.frame = self.view.bounds;
    [self.view.layer addSublayer:previewLayer];
    
    [captureSession startRunning];
    
    
    
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * documentsDirectory = [paths objectAtIndex:0];
    
    h264file = [documentsDirectory stringByAppendingPathComponent:@"test.h264"];
    [fileManager removeItemAtPath:h264file error:nil];
    [fileManager createFileAtPath:h264file contents:nil attributes:nil];
    
    fileHandle = [NSFileHandle fileHandleForWritingAtPath:h264file];
    [h264Encoder initEncode:480 height:640];
    h264Encoder.delegate = self;

}
-(void)stopCamera
{
    [captureSession stopRunning];
    [previewLayer removeFromSuperlayer];
    [fileHandle closeFile];
    fileHandle = NULL;
}


-(void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"frame captured at");
    [h264Encoder encode:sampleBuffer];
}




-(void)statusBarOrientationDidChange:(NSNotification *)notification
{
    [self setRelativeVideoOrientation];
}

-(void)setRelativeVideoOrientation
{
    switch ([[UIDevice currentDevice]orientation]) {
        case UIInterfaceOrientationPortrait:
#if defined(__IPHONE_8_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0    
            case UIInterfaceOrientationUnknown :
#endif
            connection.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
            
            
            case UIInterfaceOrientationPortraitUpsideDown:
            connection.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
            
            case UIInterfaceOrientationLandscapeLeft:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
            
            case UIInterfaceOrientationLandscapeRight:
            connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
            
        default:
            break;
    }
}




#pragma mark H264HardEncodeDelegate

-(void)gotSpsPps:(NSData *)sps pps:(NSData *)pps
{
    NSLog(@"gotSps Pps %d %d",(int)[sps length],(int)[pps length]);
    
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    
    
    
    NSData * ByteHeader = [NSData dataWithBytes:bytes length:length];
    
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:sps];
    [fileHandle writeData:ByteHeader];
    [fileHandle writeData:pps];
    
    
}

-(void)gotEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d",(int)[data length]);
    
    static int framecount = 1;
    
    if (fileHandle != NULL) {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1;
        
        NSData * ByteHeader = [NSData dataWithBytes:bytes length:length];
        
        [fileHandle writeData:ByteHeader];
        [fileHandle writeData:data];
        
        
        
    }
    
    
}









@end
