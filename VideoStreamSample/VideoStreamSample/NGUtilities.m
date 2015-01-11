//
//  NGUtilities.m
//  VideoStreamSample
//
//  Created by Nitin Gupta on 7/9/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import "NGUtilities.h"

@implementation NGUtilities

+ (NSString *)getSavingPath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [paths objectAtIndex:0];
    BOOL isDir = NO;
    NSError *error;
    if (! [[NSFileManager defaultManager] fileExistsAtPath:cachePath isDirectory:&isDir] && isDir == NO) {
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:NO attributes:nil error:&error];
    }
    return cachePath;
}


@end
