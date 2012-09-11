//
//  SQPauseCommand.m
//  Spotify Queue
//
//  Created by Red Davis on 10/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQPauseCommand.h"
#import "SQPlaybackManager.h"


@implementation SQPauseCommand

- (id)performDefaultImplementation {
    
    [[SQPlaybackManager sharedPlaybackManager] pause];
    return nil;
}

@end
