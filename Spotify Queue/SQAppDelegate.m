//
//  SQAppDelegate.m
//  Spotify Queue
//
//  Created by Red Davis on 07/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQAppDelegate.h"
#import "SQLoginWindowController.h"
#import "SQConstants.h"
#import "SQPlaybackManager.h"


@interface SQAppDelegate ()

@property (strong, nonatomic) SQLoginWindowController *loginWindowController;
@property (assign, nonatomic) BOOL loggedIn;
@property (strong, nonatomic) NSStatusItem *statusBar;
@property (readonly, nonatomic) NSMenu *statusBarMenu;
@property (readonly, nonatomic) SQPlaybackManager *playbackManager;

- (void)playbackChangedStateNotification:(NSNotification *)notification;
- (void)loggedInSuccessfulyNotification:(NSNotification *)notification;
- (void)refreshStatusBar;

@end


@implementation SQAppDelegate

- (id)init {
    
    self = [super init];
    if (self) {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loggedInSuccessfulyNotification:) name:kLoggedInSuccessfulyNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackChangedStateNotification:) name:kPlaybackManagerStartedPlaying object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackChangedStateNotification:) name:kPlaybackManagerStoppedPlaying object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackChangedStateNotification:) name:kPlaybackManagerUpdatedTracks object:nil];
    }
    
    return self;
}

- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    
    #import "appkey.c"
    
    NSError *spotifyInitializeError = nil;
    [SPSession initializeSharedSessionWithApplicationKey:[NSData dataWithBytes:g_appkey length:g_appkey_size] userAgent:@"SpotifyQueue" loadingPolicy:SPAsyncLoadingImmediate error:&spotifyInitializeError];
    
    if (spotifyInitializeError) {
        NSLog(@"Error initializing Spotify %@", spotifyInitializeError);
    }
        
    self.loginWindowController = [[SQLoginWindowController alloc] initWithWindowNibName:kSQLoginWindowControllerXibName];
    [self.loginWindowController showWindow:nil];
    
    
    self.statusBar = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusBar.title = @"SQ";
    self.statusBar.highlightMode = YES;
    [self refreshStatusBar];
}

#pragma mark - Status Bar

- (NSMenu *)statusBarMenu {
    
    NSMenu *rootMenu = [[NSMenu alloc] init];
    
    if (!self.loggedIn) {
        
        NSMenuItem *notLoggedInMenuItem = [[NSMenuItem alloc] initWithTitle:@"Login..." action:@selector(showWindow:) keyEquivalent:@""];
        notLoggedInMenuItem.target = self.loginWindowController;
        [rootMenu addItem:notLoggedInMenuItem];
    }
    else {
        
        NSMenuItem *currentTrackMenuItem = [[NSMenuItem alloc] init];
        if (self.playbackManager.currentTrack) {
            currentTrackMenuItem.title = [NSString stringWithFormat:@"Current Track: %@ - %@", self.playbackManager.currentTrack.name, self.playbackManager.currentTrack.consolidatedArtists];
        }
        else {
            currentTrackMenuItem.title = @"Not playing";
        }
        
        [rootMenu addItem:currentTrackMenuItem];
        
        [rootMenu addItem:[NSMenuItem separatorItem]];
        
        NSMenuItem *playPauseMenuItem = [[NSMenuItem alloc] init];
        playPauseMenuItem.target = self.playbackManager;
        if (self.playbackManager.isPlaying) {
            playPauseMenuItem.title = @"Pause";
            playPauseMenuItem.action = @selector(pause);
        }
        else {
            playPauseMenuItem.title = @"Play";
            playPauseMenuItem.action = @selector(play);
        }
        
        [rootMenu addItem:playPauseMenuItem];
        
        [rootMenu addItem:[NSMenuItem separatorItem]];
        
        NSMenu *queuedTracksMenu = [[NSMenu alloc] init];
        if (self.playbackManager.tracks.count > 0) {
            
            for (SPTrack *track in self.playbackManager.tracks) {
                
                NSString *trackTitle = [NSString stringWithFormat:@"%@ - %@", track.name, track.consolidatedArtists];
                NSMenuItem *trackMenuItem = [[NSMenuItem alloc] init];
                trackMenuItem.title = trackTitle;
                [queuedTracksMenu addItem:trackMenuItem];
            }
        }
        else {
            NSMenuItem *noTracksMenuItem = [[NSMenuItem alloc] init];
            noTracksMenuItem.title = @"No Tracks";
            [queuedTracksMenu addItem:noTracksMenuItem];
        }
        
        NSMenuItem *queuedTracksMenuItem = [[NSMenuItem alloc] init];
        queuedTracksMenuItem.title = @"Queued Tracks";
        [queuedTracksMenuItem setSubmenu:queuedTracksMenu];
        
        [rootMenu addItem:queuedTracksMenuItem];
    }

    [rootMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *quitMenuItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    quitMenuItem.target = [NSApplication sharedApplication];
    
    [rootMenu addItem:quitMenuItem];
    
    return rootMenu;
}

- (void)refreshStatusBar {
    
    self.statusBar.menu = self.statusBarMenu;
}

#pragma mark - Helpers

- (SQPlaybackManager *)playbackManager {
    
    return [SQPlaybackManager sharedPlaybackManager];
}

#pragma mark - Notification

- (void)playbackChangedStateNotification:(NSNotification *)notification {
    
    [self refreshStatusBar];
}

- (void)loggedInSuccessfulyNotification:(NSNotification *)notification {
    
    self.loggedIn = YES;
    
    [self refreshStatusBar];
    [self.loginWindowController close];
}

@end
