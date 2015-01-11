//
//  NGEncoder.h
//  VideoStreamSample
//
//  Created by Nitin Gupta on 7/8/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;

@interface NGEncoder : NSObject {
}
- (instancetype) initWithFilePath:(NSString*)p Height:(int)h andWidth:(int)w;
- (void) didFinishWithCompletionHandler:(void (^)(void))handler;
- (void) encodeSampleFrameFor:(CMSampleBufferRef)sampleBuffer captureOutput:(AVCaptureOutput *)captureOutput;
@end
