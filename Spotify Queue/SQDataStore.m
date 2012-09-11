//
//  SQDataStore.m
//  Spotify Queue
//
//  Created by Red Davis on 07/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQDataStore.h"


@interface SQDataStore ()

@property (readonly, nonatomic) NSUserDefaults *userDefaults;

@end


static NSString *const kTrackURLsUserDefaultsKey = @"com.reddavis.spotifyQueue.trackURLsUserDefaultsKey";


@implementation SQDataStore

#pragma mark -

+ (SQDataStore *)sharedDataSource {
    
    static SQDataStore *sharedDataSource = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDataSource = [[SQDataStore alloc] init];
    });
    
    return sharedDataSource;
}

#pragma mark - Data Management

- (void)addTrackURL:(NSURL *)url {
    
    NSMutableArray *mutableTrackURLs = [NSMutableArray arrayWithArray:self.trackURLs];
    [mutableTrackURLs addObject:url];
    [self.userDefaults setObject:mutableTrackURLs forKey:kTrackURLsUserDefaultsKey];
    [self.userDefaults synchronize];
}

- (NSArray *)trackURLs {
    
    return [self.userDefaults arrayForKey:kTrackURLsUserDefaultsKey];
}

#pragma mark - Helpers

- (NSUserDefaults *)userDefaults {
    
    return [NSUserDefaults standardUserDefaults];
}

@end
