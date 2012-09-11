//
//  SQAddTrackWindowController.h
//  Spotify Queue
//
//  Created by Red Davis on 09/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern NSString *const kSQAddTrackWindowControllerXibName;


@interface SQAddTrackWindowController : NSWindowController

@property (weak, nonatomic) IBOutlet NSTextField *trackURLTextField;
@property (weak ,nonatomic) IBOutlet NSButton *addTrackButton;

- (IBAction)addTrackButtonClicked:(id)sender;
- (IBAction)hidePanel:(id)sender;

@end
