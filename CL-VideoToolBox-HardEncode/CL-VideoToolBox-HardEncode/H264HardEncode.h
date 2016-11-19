//
//  CL-H264HardEncode.h
//  CL-VideoToolBox-HardEncode
//
//  Created by 陈龙 on 16/11/18.
//  Copyright © 2016年 陈龙. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

//添加代理方法 ： 回调callback
@protocol  H264HardEncodeDelegate <NSObject>
//得到sps 和pps
-(void)gotSpsPps:(NSData *)sps pps:(NSData *)pps;

-(void)gotEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame;


@end

@interface H264HardEncode : NSObject

-(void)initWithConfiguration;

-(void)start:(int)width height:(int)height;

-(void)initEncode:(int)width height:(int)height;

-(void)changeResolution:(int)width height:(int)height;

-(void)encode:(CMSampleBufferRef)sampleBuffer;

-(void)End;

@property(weak,nonatomic)NSString * error;

@property(weak,nonatomic)id<H264HardEncodeDelegate> delegate;


@end
