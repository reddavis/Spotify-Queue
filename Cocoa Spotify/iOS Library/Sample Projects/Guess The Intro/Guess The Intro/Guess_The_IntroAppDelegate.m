//
//  Guess_The_IntroAppDelegate.m
//  Guess The Intro
//
//  Created by Daniel Kennett on 10/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Guess_The_IntroAppDelegate.h"
#import "Guess_The_IntroViewController.h"


#error Please get an appkey.c file from developer.spotify.com and remove this error before building.
#include "appkey.c"

@implementation Guess_The_IntroAppDelegate

@synthesize window = _window;
@synthesize viewController = _viewController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Override point for customization after application launch.
	
	[SPSession initializeSharedSessionWithApplicationKey:[NSData dataWithBytes:&g_appkey length:g_appkey_size]
											   userAgent:@"com.spotify.GuessTheIntro"
										   loadingPolicy:SPAsyncLoadingImmediate
												   error:nil];
	
	[SPSession sharedSession].delegate = (id)self.viewController;
	
	self.viewController.playbackManager = [[SPPlaybackManager alloc] 
							 initWithPlaybackSession:[SPSession sharedSession]];
	self.viewController.playbackManager.delegate = self.viewController;
	
	self.window.rootViewController = self.viewController;
	[self.window makeKeyAndVisible];
	
	[self performSelector:@selector(showLoginView) withObject:nil afterDelay:0.0];
	
    return YES;
}

-(void)showLoginView {
	SPLoginViewController *controller = [SPLoginViewController loginControllerForSession:[SPSession sharedSession]];
	controller.allowsCancel = NO;
	controller.loginDelegate = self.viewController;
	[self.viewController presentModalViewController:controller animated:NO];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	/*
	 Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	 Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
	 */
	[self.viewController gameOverWithReason:@"Resigned Active"];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	/*
	 Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
	 If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
	 */
	[self.viewController gameOverWithReason:@"Backgrounded"];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	/*
	 Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	 */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	/*
	 Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
	 */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	/*
	 Called when the application is about to terminate.
	 Save data if appropriate.
	 See also applicationDidEnterBackground:.
	 */
	[[SPSession sharedSession] logout:nil];
}


@end
