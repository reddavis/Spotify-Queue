//
//  SQPlaybackManager.h
//  Spotify Queue
//
//  Created by Red Davis on 08/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import <CocoaLibSpotify/CocoaLibSpotify.h>


extern NSString *const kPlaybackManagerUpdatedTracks;
extern NSString *const kPlaybackManagerStartedPlaying;
extern NSString *const kPlaybackManagerStoppedPlaying;


@protocol SQPlaybackManagerDelegate;


@interface SQPlaybackManager : SPPlaybackManager <SPPlaybackManagerDelegate>

@property (assign, nonatomic) __unsafe_unretained id <SPPlaybackManagerDelegate, SQPlaybackManagerDelegate> delegate;
@property (strong, nonatomic) NSArray *tracks;
@property (strong, nonatomic) SPTrack *currentTrack;

+ (SQPlaybackManager *)sharedPlaybackManager;

- (void)addTrackWithURL:(NSURL *)url;
- (void)skipTrack;
- (void)play;
- (void)pause;

@end


@protocol SQPlaybackManagerDelegate <SPPlaybackManagerDelegate>
@optional
- (void)playbackManager:(SQPlaybackManager *)playbackManager didChangeTrack:(SPTrack *)track;
@end
