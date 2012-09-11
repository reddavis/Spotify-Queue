//
//  SQAddTrackCommand.m
//  Spotify Queue
//
//  Created by Red Davis on 07/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQAddTrackCommand.h"


@implementation SQAddTrackCommand

- (id)performDefaultImplementation {
    
    NSDictionary *arguments = [self evaluatedArguments];
    NSLog(@"%@", arguments);
    
    return nil;
}

@end
