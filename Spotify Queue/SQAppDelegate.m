//
//  SQAppDelegate.m
//  Spotify Queue
//
//  Created by Red Davis on 07/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQAppDelegate.h"
#import "SQWindowController.h"


@interface SQAppDelegate ()

@property (strong, nonatomic) SQWindowController *windowController;

@end


@implementation SQAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    self.windowController = [[SQWindowController alloc] initWithWindowNibName:kSQWindowControllerXibName];
    [self.windowController showWindow:self];
}

@end
