//
//  SQLoginWindowController.h
//  Spotify Queue
//
//  Created by Red Davis on 09/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString *const kSQLoginWindowControllerXibName;


@interface SQLoginWindowController : NSWindowController <SPSessionDelegate>

@property (weak, nonatomic) IBOutlet NSTextField *usernameTextField;
@property (weak, nonatomic) IBOutlet NSTextField *passwordTextField;
@property (weak, nonatomic) IBOutlet NSButton *loginButton;
@property (weak, nonatomic) IBOutlet NSProgressIndicator *largeSpinner;

- (IBAction)loginButtonClicked:(id)sender;

@end
