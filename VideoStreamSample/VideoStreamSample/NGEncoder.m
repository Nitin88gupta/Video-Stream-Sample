//
//  NGEncoder.m
//  VideoStreamSample
//
//  Created by Nitin Gupta on 7/8/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import "NGEncoder.h"
#import "NGEncoderConstants.h"

@interface NGEncoder () {
    AVAssetWriter* _avWriter;
    AVAssetWriterInput* _videoWriterInput;
    AVAssetWriterInput* _audioWriterInput;
    NSString * _path;
    
    NSMutableArray *_captureOuputCacheAudio;
    NSMutableArray *_captureOuputCacheVideo;
}
@end

@implementation NGEncoder

- (void)dealloc {
    _avWriter = nil;
    _videoWriterInput = nil;
    _audioWriterInput = nil;
    _path = nil;
    _captureOuputCacheAudio = nil;
    _captureOuputCacheVideo = nil;
}

- (instancetype) initWithFilePath:(NSString*)p Height:(int)h andWidth:(int)w {
    self = [super init];
    if (self) {
        _path = p;
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:_path error:&error];
        NSURL* url = [NSURL fileURLWithPath:_path];
        
        _avWriter = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeQuickTimeMovie error:nil];
        NSDictionary* videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                  AVVideoCodecH264, AVVideoCodecKey,
                                  [NSNumber numberWithInt: w], AVVideoWidthKey,
                                  [NSNumber numberWithInt:h], AVVideoHeightKey,
                                  [NSDictionary dictionaryWithObjectsAndKeys:
                                    @YES, AVVideoAllowFrameReorderingKey, nil],
                                   AVVideoCompressionPropertiesKey,
                                  nil];
        _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        _videoWriterInput.expectsMediaDataInRealTime = YES;
        
        AudioChannelLayout acl;
        bzero(&acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;
        NSDictionary *audioOutputSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                              [NSNumber numberWithInt: kAudioFormatAppleLossless ],AVFormatIDKey,
                                              [NSNumber numberWithInt:16], AVEncoderBitDepthHintKey,
                                              [NSNumber numberWithFloat:44100.0 ], AVSampleRateKey,
                                              [NSNumber numberWithInt:2], AVNumberOfChannelsKey,
                                              [NSData dataWithBytes: &acl length: sizeof(AudioChannelLayout) ], AVChannelLayoutKey, nil ];

        
        _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
        _audioWriterInput.expectsMediaDataInRealTime = YES;
        
        NSAssert([_avWriter canAddInput:_videoWriterInput], @"Cannot write to this type of video input" );
        NSAssert([_avWriter canAddInput:_audioWriterInput], @"Cannot write to this type of audio input" );

        [_avWriter addInput:_videoWriterInput];
        [_avWriter addInput:_audioWriterInput];

        _captureOuputCacheAudio = [[NSMutableArray alloc] initWithCapacity:0];
        _captureOuputCacheVideo = [[NSMutableArray alloc] initWithCapacity:0];
    }
    return self;
}

- (void) didFinishWithCompletionHandler:(void (^)(void))handler {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        if (_captureOuputCacheVideo && [_captureOuputCacheVideo count]) {
            [_captureOuputCacheVideo enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [_videoWriterInput appendSampleBuffer:(__bridge CMSampleBufferRef)obj];
            }];
        }
        [_captureOuputCacheVideo removeAllObjects];
        
        if (_captureOuputCacheAudio && [_captureOuputCacheAudio count]) {
            [_captureOuputCacheAudio enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [_audioWriterInput appendSampleBuffer:(__bridge CMSampleBufferRef)obj];
            }];
        }
        [_captureOuputCacheAudio removeAllObjects];
        
        [_audioWriterInput markAsFinished];
        [_videoWriterInput markAsFinished];
        
        [_avWriter finishWritingWithCompletionHandler: handler];
    });

}

- (void) encodeSampleFrameFor:(CMSampleBufferRef)sampleBuffer captureOutput:(AVCaptureOutput *)captureOutput {
    
    BOOL _shouldAddToCache = false;
    CaptureOutputType _type = [captureOutput isKindOfClass:[AVCaptureVideoDataOutput class]] ? kVideo : ([captureOutput isKindOfClass:[AVCaptureAudioDataOutput class]] ? kAudio : kUndefined) ;
    
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        if (_avWriter.status == AVAssetWriterStatusUnknown) {
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            [_avWriter startWriting];
            [_avWriter startSessionAtSourceTime:startTime];
            _shouldAddToCache  = false;
        } else if (_avWriter.status == AVAssetWriterStatusFailed) {
            NSLog(@"writer error %@", _avWriter.error.localizedDescription);
            _shouldAddToCache = true;
        } else if (_avWriter.status == AVAssetWriterStatusWriting) {
            if (_type == kAudio) {
                if ([_audioWriterInput isReadyForMoreMediaData]) {
                    if (_captureOuputCacheAudio && [_captureOuputCacheAudio count]) {
                        [_audioWriterInput appendSampleBuffer:(CMSampleBufferRef)[_captureOuputCacheAudio firstObject]];
                        [_captureOuputCacheAudio removeObjectAtIndex:0];
                    } else {
                        [_audioWriterInput appendSampleBuffer:sampleBuffer];
                    }
                    _shouldAddToCache = false;
                } else {
                    NSLog(@"[_audioWriterInput isReadyForMoreMediaData] NO");
                    _shouldAddToCache = true;
                }
            } else if (_type == kVideo){
                if ([_videoWriterInput isReadyForMoreMediaData]) {
                    if (_captureOuputCacheVideo && [_captureOuputCacheVideo count]) {
                        [_videoWriterInput appendSampleBuffer:(CMSampleBufferRef)[_captureOuputCacheVideo firstObject]];
                        [_captureOuputCacheVideo removeObjectAtIndex:0];
                    } else  {
                        [_videoWriterInput appendSampleBuffer:sampleBuffer];
                    }
                    _shouldAddToCache = false;
                } else {
                    NSLog(@"[_videoWriterInput isReadyForMoreMediaData] NO");
                    _shouldAddToCache = true;
                }
            } else {
                NSLog(@"Undefined Output Data Type");
            }
        } else {
            //UnDefined Event
            _shouldAddToCache = true;
        }
    }
    
    if (_shouldAddToCache) {
        if (_type ==kVideo) {
            [_captureOuputCacheVideo addObject:(__bridge id)(sampleBuffer)];
        } else if (_type == kAudio){
            [_captureOuputCacheVideo addObject:(__bridge id)sampleBuffer];
        }
    }
}

@end
