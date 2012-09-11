//
//  SQUserPreferences.h
//  Spotify Queue
//
//  Created by Red Davis on 09/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface SQUserPreferences : NSObject

@property (readwrite, nonatomic) NSString *username;
@property (readwrite, nonatomic) NSString *credential;

+ (SQUserPreferences *)sharedPreferences;

@end
