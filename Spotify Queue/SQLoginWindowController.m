//
//  SQLoginWindowController.m
//  Spotify Queue
//
//  Created by Red Davis on 09/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQLoginWindowController.h"
#import "SQUserPreferences.h"
#import "SQConstants.h"


@interface SQLoginWindowController ()

@property (readonly, nonatomic) SPSession *spotifySession;
@property (readonly, nonatomic) SQUserPreferences *userPreferences;

- (void)showLoginForm;
- (void)hideLoginForm;

@end


NSString *const kSQLoginWindowControllerXibName = @"SQLoginWindowController";


@implementation SQLoginWindowController

#pragma mark - Initialization

- (id)initWithWindow:(NSWindow *)window {
    
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

#pragma mark - Window Lifecycle

- (void)windowDidLoad {
    
    [super windowDidLoad];
}

- (void)awakeFromNib {
    
    self.spotifySession.delegate = self;
    
    if (self.userPreferences.username && self.userPreferences.credential) {
        
        [self hideLoginForm];
        [self.spotifySession attemptLoginWithUserName:self.userPreferences.username existingCredential:self.userPreferences.credential rememberCredentials:YES];
    }
}

#pragma mark -

- (void)showLoginForm {
    
    [self.largeSpinner stopAnimation:nil];
    [self.usernameTextField setHidden:NO];
    [self.passwordTextField setHidden:NO];
    [self.loginButton setHidden:NO];
}

- (void)hideLoginForm {
    
    [self.usernameTextField setHidden:YES];
    [self.passwordTextField setHidden:YES];
    [self.loginButton setHidden:YES];
    [self.largeSpinner startAnimation:nil];
}

#pragma mark - Actions

- (void)loginButtonClicked:(id)sender {
    
    [self.loginButton setEnabled:NO];
    [self.largeSpinner startAnimation:nil];
    
    NSString *username = self.usernameTextField.stringValue;
    NSString *password = self.passwordTextField.stringValue;
    [self.spotifySession attemptLoginWithUserName:username password:password rememberCredentials:YES];
}

#pragma mark - Helpers

- (SPSession *)spotifySession {
    
    return [SPSession sharedSession];
}

- (SQUserPreferences *)userPreferences {
    
    return [SQUserPreferences sharedPreferences];
}

#pragma mark - SPSessionDelegate

- (void)session:(SPSession *)aSession didFailToLoginWithError:(NSError *)error {
    
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert beginSheetModalForWindow:self.window modalDelegate:nil didEndSelector:nil contextInfo:nil];
    
    [self.largeSpinner stopAnimation:nil];
    [self.loginButton setEnabled:YES];
}

- (void)session:(SPSession *)aSession didEncounterNetworkError:(NSError *)error {
    
    //..Show error label
    [self showLoginForm];
}

- (void)session:(SPSession *)aSession didGenerateLoginCredentials:(NSString *)credential forUserName:(NSString *)userName {
    
    self.userPreferences.username = userName;
    self.userPreferences.credential = credential;
}

- (void)sessionDidLoginSuccessfully:(SPSession *)aSession {
    
    if (self.userPreferences.username && self.userPreferences.credential) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kLoggedInSuccessfulyNotification object:nil];
    }
}

@end
