//
//  SQQueuedTrackViewController.m
//  Spotify Queue
//
//  Created by Red Davis on 07/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQQueuedTrackViewController.h"


@interface SQQueuedTrackViewController ()

@property (strong, nonatomic) NSArray *tracks;

- (void)reloadTracks;

@end


static NSString *const kQueuedTrackTableViewCellIdentifier = @"com.reddavis.queuedTrackTableViewCellIdentifier";


@implementation SQQueuedTrackViewController

#pragma mark - Initialization

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)awakeFromNib {
    
    [self reloadTracks];
}

#pragma mark -

- (void)reloadTracks {
    
    if (self.dataSource && [self.dataSource respondsToSelector:@selector(tracksForQueuedTrackViewController:)]) {
        self.tracks = [self.dataSource tracksForQueuedTrackViewController:self];
    }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    
    return self.tracks.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    
    NSTableCellView *cell = [tableView makeViewWithIdentifier:kQueuedTrackTableViewCellIdentifier owner:self];
    cell.textField.stringValue = @"Track";
    
    return cell;
}

#pragma mark - NSTableViewDelegate

@end
