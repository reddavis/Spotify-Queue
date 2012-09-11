//
//  SQDataStore.h
//  Spotify Queue
//
//  Created by Red Davis on 07/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SQDataStore : NSObject

@property (readonly, nonatomic) NSArray *trackURLs;

+ (SQDataStore *)sharedDataSource;
- (void)addTrackURL:(NSURL *)url;

@end
