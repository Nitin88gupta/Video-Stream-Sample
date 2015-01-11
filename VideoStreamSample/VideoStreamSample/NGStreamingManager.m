//
//  NGStreamingManager.m
//  VideoStreamSample
//
//  Created by Nitin Gupta on 7/10/14.
//  Copyright (c) 2014 Nitin Gupta. All rights reserved.
//

#import "NGStreamingManager.h"
#import "NGEncoderConstants.h"

@import GameKit;

static int _nameCounter;
static NGStreamingManager *sharedInstance;

@interface NGStreamingManager()<GKSessionDelegate> {
}
@property (nonatomic, strong) GKSession *session;
@end

@implementation NGStreamingManager

+ (instancetype)sharedStreamingManager {
    @synchronized(self) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedInstance = [[NGStreamingManager alloc ] init];
        });
        return sharedInstance;
    }
}

- (id)init
{
    self = [super init];
    if (self) {
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // Nil out delegate
    _session.delegate = nil;
}

#pragma mark - Life Cycle Related
- (void)setupSession {
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    
    // Register for notifications
    [defaultCenter addObserver:self
                      selector:@selector(setupSession)
                          name:UIApplicationWillEnterForegroundNotification
                        object:nil];
    
    [defaultCenter addObserver:self
                      selector:@selector(teardownSession)
                          name:UIApplicationDidEnterBackgroundNotification
                        object:nil];

    // GKSessionModePeer: a peer advertises like a server and searches like a client.
    _session = [[GKSession alloc] initWithSessionID:nil displayName:nil sessionMode:GKSessionModePeer];
    [_session setDelegate:self];
    [_session setAvailable:YES];
    [_session setDataReceiveHandler:self withContext:NULL];
}

- (void)teardownSession {
    self.session.available = NO;
    [self.session disconnectFromAllPeers];
}

- (BOOL)publishData:(NSData *)_data {
    BOOL _result = false;
    if (_session) {
        NSError *error;
        _result = [_session sendDataToAllPeers:_data withDataMode:GKSendDataReliable error:&error];
        if (!_result) {
            NSLog(@"Error publishData: %@",[error localizedDescription]);
        }
    }
    return _result;
}

-(NSString *)movieChunkName {
    return [NSString stringWithFormat:@"myMovie_%d.mp4",_nameCounter];
}


#pragma mark - GKSessionDelegate
- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state {
    NSString *peerName = [session displayNameForPeer:peerID];
    
	switch (state) {
		case GKPeerStateAvailable: {
			NSLog(@"didChangeState: peer %@ available", peerName);
            
            BOOL shouldInvite = ([self.session.displayName compare:peerName] == NSOrderedDescending);
            
            if (shouldInvite) {
                NSLog(@"Inviting %@", peerID);
                [session connectToPeer:peerID withTimeout:kConnectionTimeout];
            } else {
                NSLog(@"Not inviting %@", peerID);
            }
			break;
        }
			
		case GKPeerStateUnavailable: {
			NSLog(@"didChangeState: peer %@ unavailable", peerName);
			break;
        }
			
		case GKPeerStateConnected: {
			NSLog(@"didChangeState: peer %@ connected", peerName);
			break;
        }
			
		case GKPeerStateDisconnected: {
			NSLog(@"didChangeState: peer %@ disconnected", peerName);
			break;
        }
			
		case GKPeerStateConnecting: {
			NSLog(@"didChangeState: peer %@ connecting", peerName);
			break;
        }
	}
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID {
	NSLog(@"didReceiveConnectionRequestFromPeer: %@", [session displayNameForPeer:peerID]);
    NSError *error;
    BOOL connectionEstablished = [session acceptConnectionFromPeer:peerID error:&error];
    if (!connectionEstablished) {
        NSLog(@"error = %@", error);
    } else {
        NSLog(@"Connected Successfully with PeerID:%@",peerID);
    }
}

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error {
	NSLog(@"connectionWithPeerFailed: peer: %@, error: %@", [session displayNameForPeer:peerID], error);
}

- (void)session:(GKSession *)session didFailWithError:(NSError *)error {
	NSLog(@"didFailWithError: error: %@", error);
	[session disconnectFromAllPeers];
}

#pragma mark - GKSession Data Receive Handler

- (void)receiveData:(NSData *)data fromPeer:(NSString *)peerID inSession:(GKSession *)session context:(void *)context {
	NSLog(@"receive data from peer: %@", peerID);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *path = [documentsDirectory stringByAppendingPathComponent:[self movieChunkName]];

    [data writeToFile:path atomically:YES];
    NSLog(@"receive Saved path = %@",path);
    _nameCounter ++;
    
    if ([_delegate respondsToSelector:@selector( onResponseRecieved:)]) {
        [_delegate onResponseRecieved:path];
    } else {
        NSAssert(0, @"_delegate unable to respond onResponseRecieved: Selector");
    }

}

@end
