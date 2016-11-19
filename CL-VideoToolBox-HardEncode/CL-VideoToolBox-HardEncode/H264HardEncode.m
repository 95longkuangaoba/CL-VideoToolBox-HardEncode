//
//  H264HardEncode.m
//VideoToolBox-HardEncode
//
//  Created by 陈龙 on 16/11/18.
//  Copyright © 2016年 陈龙. All rights reserved.
//

#import "H264HardEncode.h"
@import VideoToolbox;
@import AVFoundation;


#define YUV_FRAME_SIZE 2000
#define NUMBEROFRAMES 300
#define DURATION 12




@implementation H264HardEncode
{
    NSString * yuvFile;
    VTCompressionSessionRef EncodingSession;
    dispatch_queue_t aQueue;
    CMFormatDescriptionRef format;
    CMSampleTimingInfo timingInfo;
    BOOL initialized;
    int frameCount;
    NSData * sps;
    NSData * pps;
    
    
}
@synthesize error;

-(void)initWithConfiguration
{
    NSFileManager * fileManager = [NSFileManager defaultManager];
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * documentsDirectory = [paths objectAtIndex:0];
    
    EncodingSession = nil;
    initialized = YES;
    aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    frameCount = 0;
    sps = NULL;
    pps = NULL;
}



void didCompressH264(void * outputCallbackRefCon, void * sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags , CMSampleBufferRef sampleBuffer)
{
    NSLog(@"didCompressH264 called with status %d infoFlags %d",(int)status,(int)infoFlags);
    
    
    if (status != 0 ) {
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready");
        return;
    }
    
    
    
    H264HardEncode * encoder = (__bridge H264HardEncode *)outputCallbackRefCon;
    
    bool keyframe = !CFDictionaryContainsKey(CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0), kCMSampleAttachmentKey_NotSync);
    if (keyframe) {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        
        const uint8_t * sparameterSet;
        
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0);
        if (statusCode == noErr) {
            size_t pparameterSetSize,pparameterSetCount;
            const uint8_t * pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0);
            
            if (statusCode == noErr) {
                encoder ->sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                encoder->pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder ->_delegate) {
                    [encoder ->_delegate gotSpsPps:encoder->sps pps:encoder->pps];
                }
                
            }
        }
        
        
    }
    
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char * dataPointer;
    
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOfferset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOfferset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOfferset, AVCCHeaderLength);
            
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData * data = [[NSData alloc]initWithBytes:(dataPointer + bufferOfferset + AVCCHeaderLength) length:NALUnitLength];
            
            [encoder ->_delegate gotEncodedData:data isKeyFrame:keyframe];
            bufferOfferset += AVCCHeaderLength +NALUnitLength;
            
        }
    }
    
    
    
}


-(void)start:(int)width height:(int)height
{
    int frameSize = (width * height * 1.5);
    
    if (!initialized) {
        NSLog(@"H264:没有初始化成功");
        error = @"H264 : Not initialized";
        return;
    }
    
    dispatch_sync(aQueue, ^{
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self), &EncodingSession);
        NSLog(@"H264: VTCompressionSessionCreate %d",(int)status);
        if (status != 0) {
            NSLog(@"H264:Unable to create a H264 session");
            error = @"H264:Unable to create a H264 session";
            return ;
            
        }
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, 240);
        
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        
        
        int fd = open([yuvFile UTF8String], O_RDONLY);
        if (fd == -1) {
            NSLog(@"H264:Unable to open the file");
            error = @"H264:Unable to open the file";
            return;
        }
        
        NSMutableData * theData = [[NSMutableData alloc]initWithLength:frameSize];
        
        NSInteger actualBytes = frameSize;
        
        while (actualBytes > 0) {
            void * buffer = [theData mutableBytes];
            NSInteger bufferSize = [theData length];
            actualBytes = read(fd, buffer, bufferSize);
            if (actualBytes < frameSize) {
                [theData setLength:actualBytes];
            }
            frameCount ++;
            
            CMBlockBufferRef BlockBuffer = NULL;
            OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL, buffer, actualBytes, kCFAllocatorNull, NULL, 0, actualBytes, kCMBlockBufferAlwaysCopyDataFlag, &BlockBuffer);
            
            if (status != noErr) {
                NSLog(@"H264:CMBlockBufferCreateWithMemoryBlock failed with %d",(int)status);
                    error = @"H264:CMBlockBufferCreateWithMemoryBlock failed";
                    return;
            }
            CMSampleBufferRef sampleBuffer = NULL;
            CMFormatDescriptionRef formatDescription ;
            CMFormatDescriptionCreate(kCFAllocatorDefault, kCMMediaType_Video, 'I420', NULL, &formatDescription);
            CMSampleTimingInfo sampleTimingInfo =  {CMTimeMake(1, 300)};
            
            OSStatus statusCode = CMSampleBufferCreate(kCFAllocatorDefault, BlockBuffer, YES, NULL, NULL, formatDescription, 1, 1, &sampleTimingInfo, 0, NULL, &sampleBuffer);
            
            if (statusCode != noErr) {
                NSLog(@"H264:CMSampleBuffer Create failed with %d",(int)statusCode);
                error = @"H264:CMSampelBuffer Create failed";
                return ;
            }
            
            CFRelease(BlockBuffer);
            BlockBuffer = NULL;
            
            CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
            
            CMTime presentationTimeStamp = CMTimeMake(frameCount, 300);
            
            VTEncodeInfoFlags flags;
            
            statusCode = VTCompressionSessionEncodeFrame(EncodingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL, &flags);
            
            if (statusCode != noErr) {
                NSLog(@"H264:VTCompressionSessionEncodeFrame failed with %d",(int)statusCode);
                error = @"H264:VTCompressionSessionEncodeFrame failed";
                
                
                
                VTCompressionSessionInvalidate(EncodingSession);
                CFRelease(EncodingSession);
                EncodingSession = NULL;
                error = NULL;
                return;
            }
            
            
            
            NSLog(@"H264:VTCompressionSessionEncodeFrame Success");
            
            
            
        }
        
        VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(EncodingSession);
        
        CFRelease(EncodingSession);
        EncodingSession = NULL;
        close(fd);
        
        
    });
    
    
    
}

-(void)initEncode:(int)width height:(int)height
{
    dispatch_sync(aQueue, ^{
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self), &EncodingSession);
        NSLog(@"H264:VTCompressionSessionCreate %d",(int)status);
        
        if (status != 0) {
            NSLog(@"H264:Unable to create a H264 session");
            error = @"H264:Unable to create a H264 session";
            return ;
        
        }
        
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        
        
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        
    });
}

-(void)encode:(CMSampleBufferRef)sampleBuffer
{
    dispatch_sync(aQueue, ^{
        frameCount++;
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        CMTime presentationTimeStamp = CMTimeMake(frameCount, 1000);
        
        VTEncodeInfoFlags flags;
        
        //OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL, &flags);
        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession, imageBuffer, presentationTimeStamp, kCMTimeInvalid, NULL, NULL, &flags);
        
        
        if (statusCode != noErr) {
            NSLog(@"H264:VTCompressionSessionEncodeFrame failed with %d",(int)statusCode);
            error = @"H264:VTCompressionSessionEncodeFrame failed";
            VTCompressionSessionInvalidate(EncodingSession);
            CFRelease(EncodingSession);
            EncodingSession = NULL;
            error = NULL;
            return ;
        }
        NSLog(@"H264:VTCompressionSessionEncodeFrameSuccess");
    });
}



-(void)changeResolution:(int)width height:(int)height
{

}


-(void)End
{
    VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(EncodingSession);
    CFRelease(EncodingSession);
    EncodingSession = NULL;
    error = NULL;
}









@end
