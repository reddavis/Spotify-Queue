//
//  SQPlayCommand.m
//  Spotify Queue
//
//  Created by Red Davis on 10/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQPlayCommand.h"
#import "SQPlaybackManager.h"


@implementation SQPlayCommand

- (id)performDefaultImplementation {
    
    [[SQPlaybackManager sharedPlaybackManager] play];
    return nil;
}

@end
