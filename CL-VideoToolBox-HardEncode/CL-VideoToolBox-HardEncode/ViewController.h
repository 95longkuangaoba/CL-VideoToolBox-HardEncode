//
//  ViewController.h
//  CL-VideoToolBox-HardEncode
//
//  Created by 陈龙 on 16/11/18.
//  Copyright © 2016年 陈龙. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "H264HardEncode.h"
@import AVFoundation;


@interface ViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate,H264HardEncodeDelegate>



@end

