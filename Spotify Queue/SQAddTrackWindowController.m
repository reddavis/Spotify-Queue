//
//  SQAddTrackWindowController.m
//  Spotify Queue
//
//  Created by Red Davis on 09/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQAddTrackWindowController.h"
#import "SQPlaybackManager.h"


@interface SQAddTrackWindowController ()

@end


NSString *const kSQAddTrackWindowControllerXibName = @"SQAddTrackWindowController";


@implementation SQAddTrackWindowController

#pragma mark - Initialization

- (id)initWithWindow:(NSWindow *)window {
    
    self = [super initWithWindow:window];
    if (self) {

    }
    
    return self;
}

#pragma mark - Window Lifecycle

- (void)windowDidLoad {
    
    [super windowDidLoad];
}

#pragma mark - Actions

- (void)addTrackButtonClicked:(id)sender {
    
    if (self.trackURLTextField.stringValue.length > 0) {
        
        NSURL *trackURL = [NSURL URLWithString:self.trackURLTextField.stringValue];
        [[SQPlaybackManager sharedPlaybackManager] addTrackWithURL:trackURL];
    }
    
    [self hidePanel:nil];
}

- (void)hidePanel:(id)sender {
    
	[[NSApplication sharedApplication] endSheet:self.window];
}

@end
