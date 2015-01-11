//
//  NGViewController.m
//  VideoStreamSample
//
//  Created by Nitin Gupta on 6/19/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import "NGViewController.h"
#import "NGEncoderManager.h"
#import "NGStreamingManager.h"
#import "NGUtilities.h"

@interface NGViewController ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate,NGStreamingManagerDelegate>

@property (weak, nonatomic) IBOutlet UIButton *streamingBtn;
@property (weak, nonatomic) IBOutlet UIButton *clientNodeBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopStreamNodeBtn;

- (IBAction)streamNodeAction:(id)sender;
- (IBAction)clientNodeAction:(id)sender;
- (IBAction)stopStreamingAction:(id)sender;


@end

@implementation NGViewController
@synthesize previewLayer = _previewLayer;

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIDeviceOrientationPortrait);
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
}

- (void)viewDidUnload {
	[super viewDidUnload];
	_captureSession = nil;
	_videoOutput = nil;
    _audioOutput = nil;
	_videoInputDevice = nil;
    if (_player) {
        [_player pause];
        [_player removeAllItems];
    }
    _player = nil;
}

- (void)dealloc {
	_captureSession = nil;
	_videoOutput = nil;
    _audioOutput = nil;
	_videoInputDevice = nil;
    
    [_previewLayer removeFromSuperlayer];
    _previewLayer = nil;

    if (_player) {
        [_player pause];
        [_player removeAllItems];
    }
    _player = nil;
}

#pragma mark - Video Capturing (Streaming)
- (void)setupVideoCaptureAndStreaming {
    NSString *mediaType = AVMediaTypeVideo;
    if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType:completionHandler:)]) {
        [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
            if (granted) {
                //Granted access to mediaType
                [self setupVideoCaptureAndStreamingForAutorization:YES];
            } else {
                //Not granted access to mediaType
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[[UIAlertView alloc] initWithTitle:@"AVCam!"
                                                message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
                                               delegate:self
                                      cancelButtonTitle:@"OK"
                                      otherButtonTitles:nil] show];
                    [self setupVideoCaptureAndStreamingForAutorization:NO];
                });
            }
        }];
    } else {
        [self setupVideoCaptureAndStreamingForAutorization:YES];
    }
}

- (void)setupVideoCaptureAndStreamingForAutorization:(BOOL)granted {
    if (granted) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            //Setting up capture session
            _captureSession = [[AVCaptureSession alloc] init];
            
            //Adding video input
            AVCaptureDevice *VideoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
            if (VideoDevice) {
                NSError *error;
                _videoInputDevice = [AVCaptureDeviceInput deviceInputWithDevice:VideoDevice error:&error];
                if (!error) {
                    if ([_captureSession canAddInput:_videoInputDevice]) {
                        [_captureSession addInput:_videoInputDevice];
                    }
                    else {
                        NSLog(@"Couldn't add video input");
                    }
                } else {
                    NSLog(@"Couldn't create video input");
                }
            } else {
                NSLog(@"Couldn't create video capture device");
            }
            
            //Adding audio input
            AVCaptureDevice *audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            if (audioCaptureDevice) {
                NSError *error = nil;
                AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioCaptureDevice error:&error];
                if (!error) {
                    if ([_captureSession canAddInput:audioInput]) {
                        [_captureSession addInput:audioInput];
                    } else {
                        NSLog(@"Couldn't add audio input");
                    }
                } else {
                    NSLog(@"Couldn't create audio input");
                }
            } else {
                NSLog(@"Couldn't create audio capture device");
            }
            
            //Adding Audio Output
            _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
            [_audioOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
            if ([_captureSession canAddOutput:_audioOutput]) {
                [_captureSession addOutput:_audioOutput];
            }
            
            //Adding Video Output
            _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
            [_videoOutput setAlwaysDiscardsLateVideoFrames:YES];
            [_videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
            NSDictionary* setcapSettings = [NSDictionary dictionaryWithObjectsAndKeys:
                                            [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange], kCVPixelBufferPixelFormatTypeKey,
                                            nil];
            _videoOutput.videoSettings = setcapSettings;
            if ([_captureSession canAddOutput:_videoOutput]) {
                [_captureSession addOutput:_videoOutput];
            }
            
            //Setting image quality
            [_captureSession setSessionPreset:AVCaptureSessionPresetMedium];
            if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {
                //Check size based configs are supported before setting them
                [_captureSession setSessionPreset:AVCaptureSessionPreset640x480];
            }
            
            // make preview layer and add so that camera's view is displayed on screen
            _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession];
            [_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
            
            CGRect _rect = [[self view] frame];
            float divBy = 1.2;
            float _w = _rect.size.width/divBy;
            float _h = _rect.size.height/divBy;
            _rect = CGRectMake((_w - (_w/divBy))/2,(_h -(_h/divBy))/2,_w,_h);
            _previewLayer.frame = _rect;
            
            [self.view.layer addSublayer:_previewLayer];
            
            [[NGEncoderManager sharedManager] initializeEncoderForHeight:[[UIScreen mainScreen] bounds].size.width/2 andWidth:[[UIScreen mainScreen] bounds].size.height/2];
            
            AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
            NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
            [stillImageOutput setOutputSettings:outputSettings];
            
            [_captureSession addOutput:stillImageOutput];
            
            [self toggleCaptureSessionStatus];
            
        });
    } else {
        NSLog(@"AVCam doesn't have permission to use Camera, please change privacy settings");
    }
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition) Position {
	NSArray *Devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
	for (AVCaptureDevice *Device in Devices) {
		if ([Device position] == Position) {
			return Device;
		}
	}
	return nil;
}

- (void)cameraToggle {
	if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1) {
        //Toggle camera
		NSError *error;
		AVCaptureDeviceInput *NewVideoInput;
		AVCaptureDevicePosition position = [[_videoInputDevice device] position];
		if (position == AVCaptureDevicePositionBack) {
			NewVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self cameraWithPosition:AVCaptureDevicePositionFront] error:&error];
		} else if (position == AVCaptureDevicePositionFront) {
			NewVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self cameraWithPosition:AVCaptureDevicePositionBack] error:&error];
		} else {
            NSLog(@"UnKnow Position Type");
        }
        
		if (NewVideoInput != nil) {
			[_captureSession beginConfiguration];
			[_captureSession removeInput:_videoInputDevice];
			if ([_captureSession canAddInput:NewVideoInput]) {
				[_captureSession addInput:NewVideoInput];
				_videoInputDevice = NewVideoInput;
			} else {
				[_captureSession addInput:_videoInputDevice];
			}
			[_captureSession commitConfiguration];
		}
	}
}

- (void)toggleCaptureSessionStatus {
	if ([_captureSession isRunning]) {
        //Stop Recording
        [_captureSession stopRunning];
	} else {
        //Start Recording
        [_captureSession startRunning];
	}
}

#pragma mark - Video Player Related
- (void)setupVideoPlayer {
    [[NGStreamingManager sharedStreamingManager] setDelegate:self];
    if (_player) {
        [_player pause];
        [_player removeAllItems];
        [_playerLayer removeFromSuperlayer];
        _playerLayer = nil;
        _player = nil;
    }
    _prevItem =nil;
    
    _player = [AVQueuePlayer queuePlayerWithItems:@[]];
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
    
    CGRect _rect = [[self view] frame];
    float divBy = 1.2;
    float _w = _rect.size.width/divBy;
    float _h = _rect.size.height/divBy;
    _rect = CGRectMake((_w - (_w/divBy))/2,(_h -(_h/divBy))/2,_w,_h);
    _playerLayer.frame = _rect;
    
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _playerLayer.needsDisplayOnBoundsChange = YES;
    [[[self view] layer] addSublayer:_playerLayer];

}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate Delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
        [[NGEncoderManager sharedManager] encodeFrame:sampleBuffer captureOutput:captureOutput];
}

#pragma mark - NGStreamingManagerDelegate
-(void)onResponseRecieved:(id)response {
    AVPlayerItem *videoItem = [AVPlayerItem playerItemWithURL:[NSURL fileURLWithPath:response]];
    if (!_player) {
        [self setupVideoPlayer];
    }
    
    [_player insertItem:videoItem afterItem:_prevItem];
    
    //Updating Previous Video Item Refer;
    _prevItem = videoItem;
    if (![_player rate]) {
        //Paused, Now Setting it to play
        [_player play];
    }
}

#pragma mark - IBAction Related
- (IBAction)streamNodeAction:(id)sender {
    _ownertype = kStreamer;
    [self setupVideoCaptureAndStreaming];
    [self handleNodeButton:YES];
}

- (IBAction)clientNodeAction:(id)sender {
    _ownertype = kPlayer;
    [self setupVideoPlayer];
    [self handleNodeButton:YES];
}

- (IBAction)stopStreamingAction:(id)sender {
    
    for(AVCaptureInput *input1 in _captureSession.inputs) {
        [_captureSession removeInput:input1];
    }
    
    for(AVCaptureOutput *output1 in _captureSession.outputs) {
        [_captureSession removeOutput:output1];
    }
    [_captureSession stopRunning];
    _captureSession=nil;

    _videoOutput = nil;
    _audioOutput = nil;
	_videoInputDevice = nil;

    if (_player) {
        [_player pause];
        [_player removeAllItems];
        [_playerLayer removeFromSuperlayer];
    }
    _player = nil;
    _playerLayer = nil;
    
    if ([_captureSession isRunning]) {
        [_captureSession stopRunning];
    }
    _captureSession = nil;
    
    [_previewLayer removeFromSuperlayer];
    _previewLayer = nil;
    
    _prevItem = nil;
    
    [self handleNodeButton:NO];
}


#pragma mark - Life Cycle Related
- (void)handleNodeButton:(BOOL)_status {
    [_streamingBtn setHidden:_status];
    [_clientNodeBtn setHidden:_status];
    [_stopStreamNodeBtn setHidden:!_status];
}

@end
