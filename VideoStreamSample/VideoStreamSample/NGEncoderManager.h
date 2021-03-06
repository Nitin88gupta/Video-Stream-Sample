//
//  NGEncoderManager.h
//  VideoStreamSample
//
//  Created by Nitin Gupta on 7/9/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface NGEncoderManager : NSObject {

}

+ (instancetype)sharedManager;

- (void) initializeEncoderForHeight:(float)height andWidth:(float)width;

- (void) encodeFrame:(CMSampleBufferRef)sampleBuffer captureOutput:(AVCaptureOutput *)captureOutput;

@end
