//
//  SQQueuedTrackViewController.h
//  Spotify Queue
//
//  Created by Red Davis on 07/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SQQueuedTrackViewControllerDataSource;
@protocol SQQueuedTrackViewControllerDelegate;


@interface SQQueuedTrackViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>

@property (assign, nonatomic) id <SQQueuedTrackViewControllerDataSource> dataSource;
@property (assign, nonatomic) id <SQQueuedTrackViewControllerDelegate> delegate;

@property (weak, nonatomic) IBOutlet NSTableView *queuedTracksTableView;
@property (weak, nonatomic) IBOutlet NSButton *addTrackButton;

@end


@protocol SQQueuedTrackViewControllerDelegate <NSObject>
@optional
- (void)queuedTrackViewControllerAddTrackButtonClicked:(SQQueuedTrackViewController *)queuedTrackViewController;
@end


@protocol SQQueuedTrackViewControllerDataSource <NSObject>
- (NSArray *)tracksForQueuedTrackViewController:(SQQueuedTrackViewController *)queuedTrackViewController;
@end
