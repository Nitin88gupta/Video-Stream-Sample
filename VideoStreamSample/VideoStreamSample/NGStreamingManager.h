//
//  NGStreamingManager.h
//  VideoStreamSample
//
//  Created by Nitin Gupta on 7/10/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import <Foundation/Foundation.h>
/**
 *  Delegate is Handled for
 */
@protocol NGStreamingManagerDelegate <NSObject>
@required
-(void)onResponseRecieved:(id)response;
@end

@interface NGStreamingManager : NSObject

@property (nonatomic, assign) id<NGStreamingManagerDelegate>delegate;

/**
 *  Shared Stream Manager (Singleton Behaviour)
 *
 *  @return NGStreamingManager -> (instancetype)
 */
+ (instancetype)sharedStreamingManager;

/**
 *  Setting Up and Initiailzation GKSession;
 */
- (void)setupSession;

/**
 *  Disconnecting & Removing GKSession;
 */

- (void)teardownSession;

/**
 *  Publishing Data to all Connected Peers
 *
 *  @param _data NSData, Stream Video Data
 *
 *  @return Publishing Status Valiadation
 */
- (BOOL)publishData:(NSData *)_data;

@end
