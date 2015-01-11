//
//  NGEncoderConstants.h
//  VideoStreamSample
//
//  Created by Nitin Gupta on 7/9/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import <Foundation/Foundation.h>

#define OUTPUT_FILE_SWAPPING_POINT (256)      // 256 Bytes swapping point

#define PORT 1291

#define SERVICE_TYPE @"_http._tcp"

#define DOMAIN_NAME @""


static NSTimeInterval const kConnectionTimeout = 30.0;


typedef enum {
    kUndefined,
    kAudio,
    kVideo,
} CaptureOutputType;