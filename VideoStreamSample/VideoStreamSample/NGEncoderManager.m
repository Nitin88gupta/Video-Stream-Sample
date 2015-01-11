//
//  NGEncoderManager.m
//  VideoStreamSample
//
//  Created by Nitin Gupta on 7/9/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import "NGEncoderManager.h"
#import "sys/stat.h"
#import "sys/types.h"
#import "NGEncoder.h"
#import "NGEncoderConstants.h"
#import "NGStreamingManager.h"

static NGEncoderManager *sharedInstance;
@interface NGEncoderManager () {
@public
    NSMutableString *_filePath;
    int _height;
    int _width;
    NGEncoder *_encoder;
}
- (NSString*) makeFilePathNameFor:(long)_tsLong;
- (void) setUpEncoderFor:(NSNumber *)ts ;
- (void) publishFileAtOldPath:(NSString *)_fPath;
- (void) shutdown ;
@end

@implementation NGEncoderManager

+ (instancetype)sharedManager {
    @synchronized(self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedInstance = [[NGEncoderManager alloc] init];
        });
        return sharedInstance;
    }
}

- (id)init {
    self = [super init];
    if (self) {
        _filePath = [[NSMutableString alloc] initWithCapacity:0];
        _encoder = nil;
    }
    return self;
}

- (void)dealloc {
    _encoder = nil;
    _filePath = nil;
}

#pragma mark - Initialization Related
- (void) initializeEncoderForHeight:(float)height andWidth:(float)width {
    _height = height;
    _width = width;
}

#pragma mark - Life Cycle Related
- (void) encodeFrame:(CMSampleBufferRef)sampleBuffer captureOutput:(AVCaptureOutput *)captureOutput {
    @synchronized (self) {
        BOOL _shouldSetUPEncoder = false;
        if (!_encoder) {
            _shouldSetUPEncoder = YES;
        }
        
        struct stat st;
        fstat([[NSFileHandle fileHandleForReadingAtPath:_filePath] fileDescriptor], &st);
        NSLog(@"st.st_size = %lld",st.st_size);
        if (st.st_size > OUTPUT_FILE_SWAPPING_POINT) {
            __block NSString *_oldPath = [_filePath copy];
            __block NGEncoder *_oldEncoder = _encoder;
            [_oldEncoder didFinishWithCompletionHandler:^{
                [self publishFileAtOldPath:_oldPath];
                NSLog(@"dispatch_async Block didFinishWithCompletionHandler Called");
            }];
            _shouldSetUPEncoder = YES;
        }
        
        if (_shouldSetUPEncoder) {
            CMTime prestime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            double dPTS = (double)(prestime.value) / prestime.timescale;
            __block NSNumber* pts = [NSNumber numberWithDouble:dPTS];
            [self setUpEncoderFor:pts];
        }
        
        NSAssert(_encoder, @"_encode Can't be a nil value");
        [_encoder encodeSampleFrameFor:sampleBuffer captureOutput:captureOutput];

    }
}

- (NSString*) makeFilePathNameFor:(long)_tsLong {
    NSString* filename = [NSString stringWithFormat:@"NG_%ld.mp4", _tsLong];
    NSString* path = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];
    return path;
}

- (void) setUpEncoderFor:(NSNumber *)ts {
    NSLog(@"%s",__func__);
    _encoder = nil;
    [_filePath setString:@""];
    
    NSString *newPath = [self makeFilePathNameFor:[ts longValue]];
    _encoder = [[NGEncoder alloc] initWithFilePath:newPath Height:_height andWidth:_width];
    NSAssert(_encoder, @"_encoder Cant Be a null Value");
    
    [_filePath setString:newPath];
}

- (void)publishFileAtOldPath:(NSString *)_fPath {

    NSError *error = nil;
    NSData *fileData = [[NSData alloc] initWithContentsOfFile:_fPath options:NSDataReadingUncached error:&error];
    BOOL _result = [[NGStreamingManager sharedStreamingManager] publishData:fileData];
    if (_result) {
        //Successfully Published
        [[NSFileManager defaultManager] removeItemAtPath:_fPath error:&error];
    } else {
        //Publishing Failed
    }
}

- (void) shutdown {
    if (_encoder) {
        [_encoder didFinishWithCompletionHandler:^{
            [self publishFileAtOldPath:_filePath];
            NSLog(@"dispatch_async Block didFinishWithCompletionHandler Called");
            _encoder = nil;
            _filePath = nil;
        }];
    }
}

@end
