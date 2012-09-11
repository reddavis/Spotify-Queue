//
//  SQUserPreferences.m
//  Spotify Queue
//
//  Created by Red Davis on 09/09/2012.
//  Copyright (c) 2012 Reddavis. All rights reserved.
//

#import "SQUserPreferences.h"


@interface SQUserPreferences ()

@property (readonly, nonatomic) NSUserDefaults *userDefaults;

@end


static NSString *const kUsernameKey = @"com.reddavis.spotifyQueueUsername";
static NSString *const kCredentialKey = @"com.reddavis.spotifyQueueCredential";


@implementation SQUserPreferences

#pragma mark -

+ (SQUserPreferences *)sharedPreferences {
    
    static SQUserPreferences *userPreferences = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        userPreferences = [[SQUserPreferences alloc] init];
    });
    
    return userPreferences;
}

#pragma mark - Username

- (void)setUsername:(NSString *)username {
    
    [self.userDefaults setObject:username forKey:kUsernameKey];
    [self.userDefaults synchronize];
}

- (NSString *)username {
    
    return [self.userDefaults objectForKey:kUsernameKey];
}

#pragma mark - Credentials

- (void)setCredential:(NSString *)credential {
    
    [self.userDefaults setObject:credential forKey:kCredentialKey];
    [self.userDefaults synchronize];
}

- (NSString *)credential {
    
    return [self.userDefaults objectForKey:kCredentialKey];
}

#pragma mark - Helpers

- (NSUserDefaults *)userDefaults {
    
    return [NSUserDefaults standardUserDefaults];
}

@end
