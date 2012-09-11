//
//  SQPlaybackManager.m
//  Spotify Queue
//
//  Created by Red Davis on 08/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQPlaybackManager.h"
#import "SQConstants.h"


@interface SQPlaybackManager ()

- (void)playTrack:(SPTrack *)track;

@end


NSString *const kPlaybackManagerUpdatedTracks = @"com.spotifyQueue.playbackManagerUpdatedTracks";
NSString *const kPlaybackManagerStartedPlaying = @"com.spotifyQueue.playbackManagerStartedPlaying";
NSString *const kPlaybackManagerStoppedPlaying = @"com.spotifyQueue.playbackManagerStoppedPlaying";


@implementation SQPlaybackManager

#pragma mark -

+ (SQPlaybackManager *)sharedPlaybackManager {
    
    static SQPlaybackManager *sharedPlaybackManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPlaybackManager = [[SQPlaybackManager alloc] initWithPlaybackSession:[SPSession sharedSession]];
    });
    
    return sharedPlaybackManager;
}

#pragma mark - Initialization

- (id)initWithPlaybackSession:(SPSession *)aSession {
    
    self = [super initWithPlaybackSession:aSession];
    if (self) {
        
        self.playbackSession.playbackDelegate = self;
        [self.playbackSession setPreferredBitrate:SP_BITRATE_320k];
        self.tracks = [NSArray array];
        
        [self addObserver:self forKeyPath:@"tracks" options:0 context:nil];
        [self addObserver:self forKeyPath:@"isPlaying" options:0 context:nil];
    }
    
    return self;
}

- (void)dealloc {
    
    [self removeObserver:self forKeyPath:@"tracks"];
}

#pragma mark - Playback

- (void)play {
    
    if (self.tracks.count == 0) {
        return;
    }
    
    if (!self.currentTrack) {
        [self playTrack:[self.tracks objectAtIndex:0]];
    }
    
    [self setIsPlaying:YES];
}

- (void)pause {
    
    [self setIsPlaying:NO];
}

- (void)skipTrack {
    
    NSMutableArray *mutableTracks = [NSMutableArray arrayWithArray:self.tracks];
    [mutableTracks removeObjectAtIndex:0];
        
    if (mutableTracks.count > 0) {
        
        SPTrack *nextTrack = [mutableTracks objectAtIndex:0];
        [self playTrack:nextTrack];
    }
    else {
        self.currentTrack = nil;
    }
    
    self.tracks = [NSArray arrayWithArray:mutableTracks];
}

- (void)playTrack:(SPTrack *)track {
    
    self.currentTrack = track;
    [self playTrack:track callback:^(NSError *error) {
        
    }];
}

#pragma mark - 

- (void)addTrackWithURL:(NSURL *)url {
    
    [SPTrack trackForTrackURL:url inSession:self.playbackSession callback:^(SPTrack *track) {
        
        if (track) {
                        
            [SPAsyncLoading waitUntilLoaded:track timeout:10 then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
                                
                NSMutableArray *mutableTracks = [NSMutableArray arrayWithArray:self.tracks];
                [mutableTracks addObject:track];
                self.tracks = [NSArray arrayWithArray:mutableTracks];
            }];
        }
    }];
}

#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
        
    if ([keyPath isEqualToString:@"tracks"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kPlaybackManagerUpdatedTracks object:nil];
    }
    else if ([keyPath isEqualToString:@"isPlaying"]) {
        
        if (self.isPlaying) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kPlaybackManagerStartedPlaying object:nil];
        }
        else {
            [[NSNotificationCenter defaultCenter] postNotificationName:kPlaybackManagerStoppedPlaying object:nil];
        }
    }
}

#pragma mark - SPSessionPlaybackDelegate

- (void)sessionDidEndPlayback:(id<SPSessionPlaybackProvider>)aSession {
    
    [self skipTrack];
}

- (void)playbackManagerWillStartPlayingAudio:(SPPlaybackManager *)aPlaybackManager {
    
}

@end
