//
//  NGViewController.h
//  VideoStreamSample
//
//  Created by Nitin Gupta on 6/19/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import <UIKit/UIKit.h>

@import AVFoundation;
@import AssetsLibrary;
@import CoreMedia;

#define CAPTURE_FRAMES_PER_SECOND		20
typedef enum  {
   kStreamer,
    kPlayer,
} OwnerType;

@interface NGViewController : UIViewController {
    
    OwnerType _ownertype;
	AVCaptureSession *_captureSession;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCaptureAudioDataOutput *_audioOutput;
	AVCaptureDeviceInput *_videoInputDevice;
    
    AVQueuePlayer   *_player;
    AVPlayerLayer   *_playerLayer;
    AVPlayerItem    *_prevItem;
    
}
@property (retain) AVCaptureVideoPreviewLayer *previewLayer;

- (void)setupVideoCaptureAndStreaming;
- (void)setupVideoCaptureAndStreamingForAutorization:(BOOL)granted;
- (AVCaptureDevice*)cameraWithPosition:(AVCaptureDevicePosition) Position;
- (void)cameraToggle;
- (void)toggleCaptureSessionStatus;
@end
