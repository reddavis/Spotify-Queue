//
//  SQAddTrackCommand.m
//  Spotify Queue
//
//  Created by Red Davis on 07/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQAddTrackCommand.h"
#import "SQPlaybackManager.h"


@implementation SQAddTrackCommand

- (id)performDefaultImplementation {
    
    NSDictionary *arguments = [self evaluatedArguments];
    
    NSURL *URL = [NSURL URLWithString:[arguments objectForKey:@""]];
    [[SQPlaybackManager sharedPlaybackManager] addTrackWithURL:URL];
    
    return nil;
}

@end
