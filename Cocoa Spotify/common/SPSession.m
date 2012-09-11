//
//  SPSession.m
//  CocoaLibSpotify
//
//  Created by Daniel Kennett on 2/14/11.
/*
 Copyright (c) 2011, Spotify AB
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of Spotify AB nor the names of its contributors may 
 be used to endorse or promote products derived from this software 
 without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL SPOTIFY AB BE LIABLE FOR ANY DIRECT, INDIRECT,
 INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT 
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SPSession.h"
#import "SPErrorExtensions.h"
#import "SPTrack.h"
#import "SPTrackInternal.h"
#import "SPPlaylistContainer.h"
#import "SPUser.h"
#import "SPAlbum.h"
#import "SPArtist.h"
#import "SPPlaylist.h"
#import "SPPlaylistInternal.h"
#import "SPPlaylistFolder.h"
#import "SPURLExtensions.h"
#import "SPSearch.h"
#import "SPImage.h"
#import "SPPostTracksToInboxOperation.h"
#import "SPPlaylistContainerInternal.h"
#import "SPPlaylistFolderInternal.h"
#import "SPPlaylistItem.h"
#import "SPUnknownPlaylist.h"
#import "SPSessionInternal.h"

@interface NSObject (SPLoadedObject)
-(BOOL)checkLoaded;
@end

@interface SPSession ()

@property (nonatomic, readwrite, strong) SPUser *user;
@property (nonatomic, readwrite, strong) NSLocale *locale;

@property (nonatomic, readwrite) sp_connectionstate connectionState;
@property (nonatomic, readwrite, strong) NSMutableDictionary *playlistCache;
@property (nonatomic, readwrite, strong) NSMutableDictionary *userCache;
@property (nonatomic, readwrite, strong) NSMutableDictionary *trackCache;
@property (nonatomic, readwrite, strong) NSError *offlineSyncError;

@property (nonatomic, readwrite) sp_session *session;

@property (nonatomic, readwrite, strong) SPPlaylist *inboxPlaylist;
@property (nonatomic, readwrite, strong) SPPlaylist *starredPlaylist;
@property (nonatomic, readwrite, strong) SPPlaylistContainer *userPlaylists;

@property (nonatomic, readwrite, getter=isOfflineSyncing) BOOL offlineSyncing;
@property (nonatomic, readwrite) NSUInteger offlineTracksRemaining;
@property (nonatomic, readwrite) NSUInteger offlinePlaylistsRemaining;
@property (nonatomic, readwrite, copy) NSDictionary *offlineStatistics;

@property (nonatomic, readwrite, strong) NSMutableSet *loadingObjects;

@property (nonatomic, copy, readwrite) NSString *userAgent;
@property (nonatomic, readwrite) SPAsyncLoadingPolicy loadingPolicy;

@property (nonatomic, readwrite, copy) void (^logoutCompletionBlock) ();

-(void)checkLoadingObjects;
-(void)prodSession;

@end

#pragma mark Session Callbacks

static AudioStreamBasicDescription libSpotifyAudioDescription;

/* ------------------------  BEGIN SESSION CALLBACKS  ---------------------- */
/**
 * This callback is called when the user was logged in, but the connection to
 * Spotify was dropped for some reason.
 */
static void connection_error(sp_session *session, sp_error errorCode) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		sp_connectionstate newState = sp_session_connectionstate(session);
		NSError *error = [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			sess.connectionState = newState;
			
			if ([sess.delegate respondsToSelector:@selector(session:didEncounterNetworkError:)]) {
				[sess.delegate session:sess didEncounterNetworkError:error];
			}
		});
    }
}

/**
 * This callback is called when an attempt to login has succeeded or failed.
 */
static void logged_in(sp_session *session, sp_error errorCode) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		sp_connectionstate newState = sp_session_connectionstate(session);
		NSError *error = errorCode == SP_ERROR_OK ? nil : [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			sess.connectionState = newState;
			
			if (error != nil) {
				[[NSNotificationCenter defaultCenter] postNotificationName:SPSessionLoginDidFailNotification
																	object:sess
																  userInfo:[NSDictionary dictionaryWithObject:[NSError spotifyErrorWithCode:errorCode]
																									   forKey:SPSessionLoginDidFailErrorKey]];
				
				if ([sess.delegate respondsToSelector:@selector(session:didFailToLoginWithError:)]) {
					[sess.delegate session:sess didFailToLoginWithError:error];
				}
			}
			
			if (error == nil) {
				[[NSNotificationCenter defaultCenter] postNotificationName:SPSessionLoginDidSucceedNotification object:sess];
				
				if ([sess.delegate respondsToSelector:@selector(sessionDidLoginSuccessfully:)]) {
					[sess.delegate sessionDidLoginSuccessfully:sess];
				}
			}
			
		});
    }
}

/**
 * This callback is called when the session has logged out of Spotify.
 *
 * @sa sp_session_callbacks#logged_out
 */
static void logged_out(sp_session *session) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
    
	@autoreleasepool {
		
		sp_connectionstate newState = sp_session_connectionstate(session);
		
		dispatch_async(dispatch_get_main_queue(), ^{
			sess.connectionState = newState;
			
			[[NSNotificationCenter defaultCenter] postNotificationName:SPSessionDidLogoutNotification object:sess];
			
			if ([sess.delegate respondsToSelector:@selector(sessionDidLogOut:)]) {
				[sess.delegate sessionDidLogOut:sess];
			}
			
			if (sess.logoutCompletionBlock) {
				sess.logoutCompletionBlock();
				sess.logoutCompletionBlock = nil;
			}
			
		});
    }
}

/**
 * Called when processing needs to take place on the main thread.
 *
 * You need to call sp_session_process_events() in the main thread to get
 * libspotify to do more work. Failure to do so may cause request timeouts,
 * or a lost connection.
 *
 * The most straight forward way to do this is using Unix signals. We use
 * SIGIO. signal(7) in Linux says "I/O now possible" which sounds reasonable.
 *
 * @param[in]  session    Session
 *
 * @note This function is called from an internal session thread - you need
 * to have proper synchronization!
 */
static void notify_main_thread(sp_session *session) {
    
    SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
    
	@synchronized (sess) {
		dispatch_async([SPSession libSpotifyQueue], ^{
			[sess prodSession];
		});
	}
}

/**
 * This callback is called for log messages.
 */
static void log_message(sp_session *session, const char *data) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		NSString *message = [NSString stringWithUTF8String:data];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([sess.delegate respondsToSelector:@selector(session:didLogMessage:)]) {
				[sess.delegate session:sess didLogMessage:message];
			}
		});
    }
}

/**
 * Callback called when libspotify has new metadata available
 *
 * If you have metadata cached outside of libspotify, you should purge
 * your caches and fetch new versions.
 */
static void metadata_updated(sp_session *session) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		// Call this on the libSpotify queue
		[sess checkLoadingObjects];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if ([sess.delegate respondsToSelector:@selector(sessionDidChangeMetadata:)]) {
				[sess.delegate sessionDidChangeMetadata:sess];
			}
		});
    }
}

/**
 * Called when the access point wants to display a message to the user
 *
 * In the desktop client, these are shown in a blueish toolbar just below the
 * search box.
 *
 * @param[in]  session    Session
 * @param[in]  message    String in UTF-8 format.
 */
static void message_to_user(sp_session *session, const char *msg) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
    @autoreleasepool {
		
		NSString *message = [NSString stringWithUTF8String:msg];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([sess.delegate respondsToSelector:@selector(session:recievedMessageForUser:)]) {
				[sess.delegate session:sess recievedMessageForUser:message];
			}
		});
    }
}


/**
 * Called when there is decompressed audio data available.
 *
 * @param[in]  session    Session
 * @param[in]  format     Audio format descriptor sp_audioformat
 * @param[in]  frames     Points to raw PCM data as described by format
 * @param[in]  num_frames Number of available samples in frames.
 *                        If this is 0, a discontinuity has occured (such as after a seek). The application
 *                        should flush its audio fifos, etc.
 *
 * @return                Number of frames consumed.
 *                        This value can be used to rate limit the output from the library if your
 *                        output buffers are saturated. The library will retry delivery in about 100ms.
 *
 * @note This function is called from an internal session thread - you need to have proper synchronization!
 *
 * @note This function must never block. If your output buffers are full you must return 0 to signal
 *       that the library should retry delivery in a short while.
 */
static int music_delivery(sp_session *session, const sp_audioformat *format, const void *frames, int num_frames) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		id <SPSessionAudioDeliveryDelegate> audioDeliveryDelegate = sess.audioDeliveryDelegate;
		if (audioDeliveryDelegate != nil) {
			
			if (format->sample_rate != (float)libSpotifyAudioDescription.mSampleRate || format->channels != libSpotifyAudioDescription.mChannelsPerFrame) {
				// Update the libSpotify audio description to match the current data
				libSpotifyAudioDescription.mSampleRate = (float)format->sample_rate;
				libSpotifyAudioDescription.mBytesPerPacket = format->channels * sizeof(SInt16);
				libSpotifyAudioDescription.mBytesPerFrame = libSpotifyAudioDescription.mBytesPerPacket;
				libSpotifyAudioDescription.mChannelsPerFrame = format->channels;
			}
			
			int framesConsumed = (int)[audioDeliveryDelegate session:sess
											shouldDeliverAudioFrames:frames
															 ofCount:num_frames
												   streamDescription:libSpotifyAudioDescription];
			return framesConsumed;
		}
		
		id <SPSessionPlaybackDelegate> playbackDelegate = sess.playbackDelegate;
		if ([playbackDelegate respondsToSelector:@selector(session:shouldDeliverAudioFrames:ofCount:format:)]) {
			int framesConsumed = (int)[playbackDelegate session:sess
									   shouldDeliverAudioFrames:frames
														ofCount:num_frames
														 format:format]; 
			return framesConsumed;
		}
    }
	
	return num_frames;
}

/**
 * Music has been paused because only one account may play music at the same time.
 *
 * @param[in]  session    Session
 */
static void play_token_lost(sp_session *session) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			sess.playing = NO;
			if ([[sess playbackDelegate] respondsToSelector:@selector(sessionDidLosePlayToken:)]) {
				[sess.playbackDelegate sessionDidLosePlayToken:sess];
			}
		});
    }
}

/**
 * End of track.
 * Called when the currently played track has reached its end.
 *
 * @note This function is invoked from the same internal thread
 * as the music delivery callback
 *
 * @param[in]  session    Session
 */
static void end_of_track(sp_session *session) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			sess.playing = NO;
			
			SEL selector = @selector(sessionDidEndPlayback:);
			if ([[sess playbackDelegate] respondsToSelector:selector]) { 
				[(NSObject *)[sess playbackDelegate] performSelectorOnMainThread:selector
																	  withObject:sess
																   waitUntilDone:NO];
			}
		});
    }
}

// Streaming error. Called when streaming cannot start or continue
static void streaming_error(sp_session *session, sp_error errorCode) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		NSError *error = [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([[sess playbackDelegate] respondsToSelector:@selector(session:didEncounterStreamingError:)]) {
				[(id <SPSessionPlaybackDelegate>)sess.playbackDelegate session:sess didEncounterStreamingError:error];
			}
		});
	}
}

// Called when offline synchronization status is updated
static void offline_status_updated(sp_session *session) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		sp_offline_sync_status status;
		sp_offline_sync_get_status(session, &status);
		
		NSUInteger offlineTracksRemaining = sp_offline_tracks_to_sync(session);
		NSUInteger offlinePlaylistsRemaining = sp_offline_num_playlists(session);
		BOOL syncing = status.syncing;
				
		NSMutableDictionary *mutableStats = [NSMutableDictionary dictionary];
		[mutableStats setValue:[NSNumber numberWithInt:status.copied_tracks] forKey:SPOfflineStatisticsCopiedTrackCountKey];
		[mutableStats setValue:[NSNumber numberWithLongLong:status.copied_bytes] forKey:SPOfflineStatisticsCopiedTrackSizeKey];
		
		[mutableStats setValue:[NSNumber numberWithInt:status.done_tracks] forKey:SPOfflineStatisticsDoneTrackCountKey];
		[mutableStats setValue:[NSNumber numberWithLongLong:status.done_bytes] forKey:SPOfflineStatisticsDoneTrackSizeKey];
		
		[mutableStats setValue:[NSNumber numberWithInt:status.queued_tracks] forKey:SPOfflineStatisticsQueuedTrackCountKey];
		[mutableStats setValue:[NSNumber numberWithLongLong:status.queued_bytes] forKey:SPOfflineStatisticsQueuedTrackSizeKey];
		
		[mutableStats setValue:[NSNumber numberWithInt:status.error_tracks] forKey:SPOfflineStatisticsFailedTrackCountKey];
		[mutableStats setValue:[NSNumber numberWithInt:status.willnotcopy_tracks] forKey:SPOfflineStatisticsWillNotCopyTrackCountKey];
		[mutableStats setValue:[NSNumber numberWithBool:status.syncing] forKey:SPOfflineStatisticsIsSyncingKey];
		
		for (id playlistOrFolder in [sess.playlistCache allValues]) {
			if ([playlistOrFolder respondsToSelector:@selector(offlineSyncStatusMayHaveChanged)])
				[playlistOrFolder offlineSyncStatusMayHaveChanged];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			sess.offlineTracksRemaining = offlineTracksRemaining;
			sess.offlinePlaylistsRemaining = offlinePlaylistsRemaining;
			sess.offlineSyncing = syncing;
			sess.offlineStatistics = [NSDictionary dictionaryWithDictionary:mutableStats];
		});
	}
}
	
	// Called when an error occurs during offline syncing.
static void offline_error(sp_session *session, sp_error error) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	NSError *err = [NSError spotifyErrorWithCode:error];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		sess.offlineSyncError = err;
	});
}

static void credentials_blob_updated(sp_session *session, const char *blob) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		NSString *credentialsBlob = [NSString stringWithUTF8String:blob];
		const char *user_name = sp_session_user_name(session);
		NSString *loginUserName = user_name == NULL ? nil : [NSString stringWithUTF8String:user_name];
		if (loginUserName.length == 0) loginUserName = nil;
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			SEL selector = @selector(session:didGenerateLoginCredentials:forUserName:);
			
			if ([[sess delegate] respondsToSelector:selector]) {
				[(id <SPSessionDelegate>)[sess delegate] session:sess
									 didGenerateLoginCredentials:credentialsBlob
													 forUserName:loginUserName];
			}
		});
	}
}

static void connectionstate_updated(sp_session *session) {
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	sp_connectionstate state = sp_session_connectionstate(session);

	@autoreleasepool {
		dispatch_async(dispatch_get_main_queue(), ^{
			sess.connectionState = state;
		});
	}
}

static void scrobble_error(sp_session *session, sp_error error) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		
		NSError *err = [NSError spotifyErrorWithCode:error];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			SEL selector = @selector(session:didEncounterScrobblingError:);
			
			if ([[sess delegate] respondsToSelector:selector]) {
				[(id <SPSessionDelegate>)[sess delegate] session:sess
									 didEncounterScrobblingError:err];
			}
		});
	}
}

static void private_session_mode_changed(sp_session *session, bool is_private) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	
	@autoreleasepool {
		dispatch_async(dispatch_get_main_queue(), ^{
			[sess setPrivateSessionFromLibSpotifyUpdate:is_private];
		});
	}
}

#if TARGET_OS_IPHONE

#import "SPLoginViewController.h"
#import "SPLoginViewControllerInternal.h"

static void show_signup_page(sp_session *session, sp_signup_page page, bool pageIsLoading, int featureMask, const char *recentUserName) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	@autoreleasepool {
		dispatch_async(dispatch_get_main_queue(), ^{
			[[SPLoginViewController loginControllerForSession:sess] handleShowSignupPage:page
																				 loading:pageIsLoading
																			 featureMask:featureMask
																		  recentUserName:[NSString stringWithUTF8String:recentUserName]];
		});
	}
}

static void show_signup_error_page(sp_session *session, sp_signup_page page, sp_error error) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	@autoreleasepool {
		dispatch_async(dispatch_get_main_queue(), ^{
			[[SPLoginViewController loginControllerForSession:sess] handleShowSignupErrorPage:page
																						error:[NSError spotifyErrorWithCode:error]];
		});
	}
}

static void connect_to_facebook(sp_session *session, const char **permissions, int permission_count) {
	
	SPSession *sess = (__bridge SPSession *)sp_session_userdata(session);
	@autoreleasepool {
		NSMutableArray *permissionStrs = [NSMutableArray arrayWithCapacity:permission_count];
		for (int i = 0; i < permission_count; i++)
			[permissionStrs addObject:[NSString stringWithUTF8String:permissions[i]]];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[[SPLoginViewController loginControllerForSession:sess] handleConnectToFacebookWithPermissions:permissionStrs];
		});
	}
}

#endif

static sp_session_callbacks _callbacks = {
	&logged_in,
	&logged_out,
	&metadata_updated,
	&connection_error,
	&message_to_user,
	&notify_main_thread,
	&music_delivery,
	&play_token_lost,
	&log_message,
	&end_of_track,
	&streaming_error,
	NULL, //userinfo_updated
	NULL, //start_playback
	NULL, //stop_playback
	NULL, //get_audio_buffer_stats
	&offline_status_updated,
	&offline_error,
	&credentials_blob_updated,
	&connectionstate_updated,
#if TARGET_OS_IPHONE
	&show_signup_page,
	&show_signup_error_page,
	&connect_to_facebook,
	NULL,
#endif
	&scrobble_error,
	&private_session_mode_changed
};

#pragma mark -

static NSString * const kSPSessionKVOContext = @"kSPSessionKVOContext";

@implementation SPSession {
	BOOL _playing;
	BOOL _cachedIsUsingNormalization;
	BOOL _privateSession;
}

static dispatch_queue_t libspotify_global_queue;

+(void)initialize {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		libspotify_global_queue = dispatch_queue_create("com.spotify.CocoaLibSpotify", DISPATCH_QUEUE_SERIAL);
	});
}

+(dispatch_queue_t)libSpotifyQueue {
	return libspotify_global_queue;
}

+(BOOL)spotifyClientInstalled {
#if TARGET_OS_IPHONE
	return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"spotify:"]];
#else
	return [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.spotify.client"] != nil;
#endif
}

+(BOOL)launchSpotifyClientIfInstalled {
	if (![self spotifyClientInstalled]) return NO;
#if TARGET_OS_IPHONE
	return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"spotify:"]];
#else
	return [[NSWorkspace sharedWorkspace] launchAppWithBundleIdentifier:@"com.spotify.client"
																options:NSWorkspaceLaunchDefault
										 additionalEventParamDescriptor:nil
													   launchIdentifier:NULL];
#endif
}

static SPSession *sharedSession;

+(SPSession *)sharedSession {
	return sharedSession;
}

+(BOOL)initializeSharedSessionWithApplicationKey:(NSData *)appKey
									   userAgent:(NSString *)aUserAgent
								   loadingPolicy:(SPAsyncLoadingPolicy)policy
										   error:(NSError **)error {
	
	sharedSession = [[SPSession alloc] initWithApplicationKey:appKey
													userAgent:aUserAgent
												loadingPolicy:policy
														error:error];
	if (sharedSession == nil)
		return NO;
	
	return YES;
}

+(NSString *)libSpotifyBuildId {
	__block NSString *buildId = nil;
	SPDispatchSyncIfNeeded(^() { buildId = [NSString stringWithUTF8String:sp_build_id()]; });
	return buildId;
}

-(id)init {
	// This will always fail.
	return [self initWithApplicationKey:nil userAgent:nil loadingPolicy:SPAsyncLoadingManual error:nil];
}

-(id)initWithApplicationKey:(NSData *)appKey
				  userAgent:(NSString *)aUserAgent
			  loadingPolicy:(SPAsyncLoadingPolicy)policy
					  error:(NSError **)error {
	
	if ((self = [super init])) {
        
        self.userAgent = aUserAgent;
		self.loadingPolicy = policy;
        
        self.trackCache = [[NSMutableDictionary alloc] init];
        self.userCache = [[NSMutableDictionary alloc] init];
		self.playlistCache = [[NSMutableDictionary alloc] init];
		self.loadingObjects = [[NSMutableSet alloc] init];
		
		self.connectionState = SP_CONNECTION_STATE_UNDEFINED;
		
		[self addObserver:self
               forKeyPath:@"connectionState"
                  options:0
                  context:(__bridge void *)kSPSessionKVOContext];
		
		[self addObserver:self
			   forKeyPath:@"starredPlaylist.items"
				  options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
				  context:(__bridge void *)kSPSessionKVOContext];
		
		if (appKey == nil || [aUserAgent length] == 0) {
			
			if (error && appKey == nil)
				*error = [NSError spotifyErrorWithCode:SP_ERROR_BAD_APPLICATION_KEY];
			
			if (error && [aUserAgent length] == 0)
				*error = [NSError spotifyErrorWithCode:SP_ERROR_BAD_USER_AGENT];
			
			return nil;
		}
		
		// Find the application support directory for settings
		
		NSString *applicationSupportDirectory = nil;
		NSArray *potentialDirectories = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
																			NSUserDomainMask,
																			YES);
		
		if ([potentialDirectories count] > 0) {
			applicationSupportDirectory = [[potentialDirectories objectAtIndex:0] stringByAppendingPathComponent:aUserAgent];
		} else {
			applicationSupportDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:aUserAgent];
		}
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:applicationSupportDirectory]) {
			if (![[NSFileManager defaultManager] createDirectoryAtPath:applicationSupportDirectory
										   withIntermediateDirectories:YES
															attributes:nil
																 error:error]) {
				return nil;
			}
		}
		
		// Find the caches directory for cache
		
		NSString *cacheDirectory = nil;
		
		NSArray *potentialCacheDirectories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
																				 NSUserDomainMask,
																				 YES);
		
		if ([potentialCacheDirectories count] > 0) {
			cacheDirectory = [[potentialCacheDirectories objectAtIndex:0] stringByAppendingPathComponent:aUserAgent];
		} else {
			cacheDirectory = [NSTemporaryDirectory() stringByAppendingPathComponent:aUserAgent];
		}
		
		if (![[NSFileManager defaultManager] fileExistsAtPath:cacheDirectory]) {
			if (![[NSFileManager defaultManager] createDirectoryAtPath:cacheDirectory
										   withIntermediateDirectories:YES
															attributes:nil
																 error:error]) {
				return nil;
			}
		}
		
		// Set the audio description - other fields will be filled in when we start getting audio.
		memset(&libSpotifyAudioDescription, 0, sizeof(libSpotifyAudioDescription));
		libSpotifyAudioDescription.mFormatID = kAudioFormatLinearPCM;
		libSpotifyAudioDescription.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked | kAudioFormatFlagsNativeEndian;
		libSpotifyAudioDescription.mFramesPerPacket = 1;
		libSpotifyAudioDescription.mBitsPerChannel = 16;
		libSpotifyAudioDescription.mReserved = 0;
		
		__block NSError *creationError = nil;
		
		SPDispatchSyncIfNeeded(^{
			
			sp_session_config config;
			memset(&config, 0, sizeof(config));
			
			config.api_version = SPOTIFY_API_VERSION;
			config.application_key = [appKey bytes];
			config.application_key_size = [appKey length];
			config.user_agent = [aUserAgent UTF8String];
			config.settings_location = [applicationSupportDirectory UTF8String];
			config.cache_location = [cacheDirectory UTF8String];
			config.userdata = (__bridge void *)self;
			config.callbacks = &_callbacks;
			
			sp_error createErrorCode = sp_session_create(&config, &_session);
			if (createErrorCode != SP_ERROR_OK) {
				self.session = NULL;
				creationError = [NSError spotifyErrorWithCode:createErrorCode];
			} else {
				_cachedIsUsingNormalization = sp_session_get_volume_normalization(_session);
			}

		});
		
		if (creationError != nil) {
			if (*error != NULL)
				*error = creationError;
			
			return nil;
		}
	}
	
	return self;
}

-(void)attemptLoginWithUserName:(NSString *)userName 
					   password:(NSString *)password
			rememberCredentials:(BOOL)rememberMe {
	
	if (userName.length == 0 || password.length == 0)
		return;
	
	[self logout:^{
		dispatch_async([SPSession libSpotifyQueue], ^{ sp_session_login(self.session, [userName UTF8String], [password UTF8String], rememberMe, NULL); });
	}];
}

-(void)attemptLoginWithUserName:(NSString *)userName
			 existingCredential:(NSString *)credential
			rememberCredentials:(BOOL)rememberMe {
	
	if ([userName length] == 0 || [credential length] == 0)
		return;
	
	[self logout:^{
		dispatch_async([SPSession libSpotifyQueue], ^{ sp_session_login(self.session, [userName UTF8String], NULL, rememberMe, [credential UTF8String]); });
	}];
}

-(void)fetchLoginUserName:(void (^)(NSString *loginUserName))block {
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		
		if (self.session == NULL)
			return;
		
		const char *user_name = sp_session_user_name(self.session);
		NSString *loginUserName = user_name == NULL ? nil : [NSString stringWithUTF8String:user_name];
		if (loginUserName.length == 0) loginUserName = nil;
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(loginUserName); });
	});
}

-(void)attemptLoginWithStoredCredentials:(SPErrorableOperationCallback)block {

	dispatch_async([SPSession libSpotifyQueue], ^{
		
		if (self.session == NULL)
			return;
		
		sp_error errorCode = sp_session_relogin(self.session);
		NSError *error = nil;
		if (errorCode != SP_ERROR_OK)
			error = [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(error); });
	});
}

-(void)fetchStoredCredentialsUserName:(void (^)(NSString *storedUserName))block {
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		
		NSString *name = nil;
		
		if (self.session != NULL) {
			char userNameBuffer[300];
			int userNameLength = sp_session_remembered_user(self.session, (char *)&userNameBuffer, sizeof(userNameBuffer));
			
			if (userNameLength > -1) {
				NSString *userName = [NSString stringWithUTF8String:(char *)&userNameBuffer];
				if (userName.length > 0)
					name = userName;
			}
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(name); });
	});
}

-(void)forgetStoredCredentials {
	dispatch_async([SPSession libSpotifyQueue], ^() { if (self.session) sp_session_forget_me(self.session); });
}

-(void)flushCaches:(void (^)())completionBlock {
	dispatch_async([SPSession libSpotifyQueue], ^() {
		if (self.session) sp_session_flush_caches(self.session); 
		dispatch_async(dispatch_get_main_queue(), ^{
			if (completionBlock) completionBlock();
		});
	});
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == (__bridge void *)kSPSessionKVOContext) {
		
		if ([keyPath isEqualToString:@"starredPlaylist.items"]) {
			// Bit of a hack to KVO the starred-ness of tracks.
			
			NSArray *oldStarredItems = [change valueForKey:NSKeyValueChangeOldKey];
			if (oldStarredItems == (id)[NSNull null])
				oldStarredItems = nil;
			
			NSArray *newStarredItems = [change valueForKey:NSKeyValueChangeNewKey];
			if (newStarredItems == (id)[NSNull null])
				newStarredItems = nil;
			
			NSMutableSet *someItems = [NSMutableSet set];
			[someItems addObjectsFromArray:newStarredItems];
			[someItems addObjectsFromArray:oldStarredItems];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				for (SPPlaylistItem *playlistItem in someItems) {
					if (playlistItem.itemClass == [SPTrack class]) {
						
						SPTrack *track = playlistItem.item;
						dispatch_async([SPSession libSpotifyQueue], ^() { 
							BOOL starred = sp_track_is_starred(self.session, track.track);
							dispatch_async(dispatch_get_main_queue(), ^() { [track setStarredFromLibSpotifyUpdate:starred]; });
						});
					}
				}
			});
			
			return;
            
        } else if ([keyPath isEqualToString:@"connectionState"]) {
            
            if (self.connectionState == SP_CONNECTION_STATE_LOGGED_IN || self.connectionState == SP_CONNECTION_STATE_OFFLINE) {
                
				if (self.inboxPlaylist == nil) {
					dispatch_async([SPSession libSpotifyQueue], ^() {
						sp_playlist *pl = sp_session_inbox_create(self.session);
						if (pl == NULL) return;
						SPPlaylist *playlist = [self playlistForPlaylistStruct:pl];
						dispatch_async(dispatch_get_main_queue(), ^() { self.inboxPlaylist = playlist; });
						sp_playlist_release(pl);
					});
				}
				
                if (self.starredPlaylist == nil) {
					dispatch_async([SPSession libSpotifyQueue], ^() {
						sp_playlist *pl = sp_session_starred_create(self.session);
						if (pl == NULL) return;
						SPPlaylist *playlist = [self playlistForPlaylistStruct:pl];
						dispatch_async(dispatch_get_main_queue(), ^() { self.starredPlaylist = playlist; });
						sp_playlist_release(pl);
					});
                }
                
                if (self.userPlaylists == nil) {
					dispatch_async([SPSession libSpotifyQueue], ^() {
						sp_playlistcontainer *plc = sp_session_playlistcontainer(self.session);
						if (plc == NULL) return;
						SPPlaylistContainer *container = [[SPPlaylistContainer alloc] initWithContainerStruct:plc inSession:self];
						dispatch_async(dispatch_get_main_queue(), ^() { self.userPlaylists = container; });
					});
                }
                
				dispatch_async([SPSession libSpotifyQueue], ^() {
					sp_user *userStruct = sp_session_user(self.session);
					SPUser *newUser = [SPUser userWithUserStruct:userStruct inSession:self];
					dispatch_async(dispatch_get_main_queue(), ^() { self.user = newUser; });
				});
				
				dispatch_async([SPSession libSpotifyQueue], ^() {
					int encodedLocale = sp_session_user_country(self.session);
					char localeId[3];
					localeId[0] = encodedLocale >> 8 & 0xFF;
					localeId[1] = encodedLocale & 0xFF;
					localeId[2] = 0;
					NSString *localeString = [NSString stringWithUTF8String:(const char *)&localeId];
					NSLocale *newLocale = [[NSLocale alloc] initWithLocaleIdentifier:localeString];
					dispatch_async(dispatch_get_main_queue(), ^() { self.locale = newLocale; });
				});
			}
            
            if (self.connectionState == SP_CONNECTION_STATE_LOGGED_OUT) {
				self.inboxPlaylist = nil;
				self.starredPlaylist = nil;
				self.userPlaylists = nil;
				self.user = nil;
				self.locale = nil;
            }
            return;
        }
    } 
    
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

-(void)logout:(void (^)())completionBlock {
	[self.trackCache removeAllObjects];
	[self.userCache removeAllObjects];
	self.inboxPlaylist = nil;
	self.starredPlaylist = nil;
	self.userPlaylists = nil;
	self.user = nil;
	self.locale = nil;
	self.connectionState = SP_CONNECTION_STATE_LOGGED_OUT;
	
	sp_session *outgoing_session = _session;
	
	if (!outgoing_session) {
		if (completionBlock) completionBlock();
		return;
	}
	
	self.logoutCompletionBlock = completionBlock;
	
	dispatch_async([SPSession libSpotifyQueue], ^() {
		
		[self.playlistCache removeAllObjects];
		sp_connectionstate state = sp_session_connectionstate(outgoing_session);
		
		if (state == SP_CONNECTION_STATE_LOGGED_OUT || state == SP_CONNECTION_STATE_UNDEFINED) {
			dispatch_async(dispatch_get_main_queue(), ^{
				self.logoutCompletionBlock = nil;
				if (completionBlock) completionBlock();
				return;
			});
		}
		
		sp_session_logout(outgoing_session);
	});
}

@synthesize connectionState;
@synthesize playlistCache;
@synthesize trackCache;
@synthesize userCache;
@synthesize inboxPlaylist;
@synthesize starredPlaylist;
@synthesize userPlaylists;
@synthesize user;
@synthesize locale;
@synthesize offlineSyncError;
@synthesize userAgent;
@synthesize loadingPolicy;
@synthesize loadingObjects;
@synthesize logoutCompletionBlock;

+(NSSet *)keyPathsForValuesAffectingLoaded {
	return [NSSet setWithObjects:@"inboxPlaylist", @"starredPlaylist", @"user", @"locale", @"userPlaylists", nil];
}

-(BOOL)isLoaded {
	return self.inboxPlaylist != nil &&
	self.starredPlaylist != nil &&
	self.user != nil &&
	self.locale != nil &&
	self.userPlaylists != nil;
}

#pragma mark - Social and Scrobbling

-(BOOL)isPrivateSession {
	return _privateSession;
}

-(void)setPrivateSession:(BOOL)privateSession {
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		sp_session_set_private_session(self.session, privateSession);
	});
	
	_privateSession = privateSession;
}

-(void)setPrivateSessionFromLibSpotifyUpdate:(BOOL)isPrivate {
	[self willChangeValueForKey:@"privateSession"];
	_privateSession = isPrivate;
	[self didChangeValueForKey:@"privateSession"];
}

-(void)setScrobblingState:(sp_scrobbling_state)state forService:(sp_social_provider)service callback:(SPErrorableOperationCallback)block {
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		sp_error errorCode = sp_session_set_scrobbling(self.session, service, state);
		NSError *error = nil;
		if (errorCode != SP_ERROR_OK)
			error = [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(error); });
	});
}

-(void)setScrobblingUserName:(NSString *)userName password:(NSString *)password forService:(sp_social_provider)service callback:(SPErrorableOperationCallback)block {
	
	if (userName.length == 0 || password.length == 0) {
		if (block) block([NSError spotifyErrorWithCode:SP_ERROR_INVALID_INDATA]);
		return;
	}
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		sp_session_set_social_credentials(self.session, service, userName.UTF8String, password.UTF8String);
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(nil); });
	});
}

-(void)fetchScrobblingStateForService:(sp_social_provider)service callback:(void (^)(sp_scrobbling_state state, NSError *error))block {
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		
		sp_scrobbling_state out_state;
		sp_error errorCode = sp_session_is_scrobbling(self.session, service, &out_state);
		
		NSError *error = nil;
		if (errorCode != SP_ERROR_OK)
			error = [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(out_state, error); });
	});
}

-(void)fetchScrobblingAllowedForService:(sp_social_provider)service callback:(void (^)(BOOL scrobblingAllowed, NSError *error))block {
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		
		bool out_state = NO;
		sp_error errorCode = sp_session_is_scrobbling_possible(self.session, service, &out_state);
		
		NSError *error = nil;
		if (errorCode != SP_ERROR_OK)
			error = [NSError spotifyErrorWithCode:errorCode];
		
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(out_state, error); });
	});
}

#pragma mark - Block Getters

-(SPTrack *)trackForTrackStruct:(sp_track *)spTrack {
    // WARNING: This MUST be called on the LibSpotify worker queue.
	
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
	
	NSValue *ptrValue = [NSValue valueWithPointer:spTrack];
	SPTrack *cachedTrack = [self.trackCache objectForKey:ptrValue];
	
    if (cachedTrack != nil) {
        // track may have been cached without album browse specific fields
        [cachedTrack updateAlbumBrowseSpecificMembers];
        return cachedTrack;
    }
    
	cachedTrack = [[SPTrack alloc] initWithTrackStruct:spTrack
											 inSession:self];
	
    [self.trackCache setObject:cachedTrack forKey:ptrValue];
    return cachedTrack;
}

-(SPUser *)userForUserStruct:(sp_user *)spUser {
    // WARNING: This MUST be called on the LibSpotify worker queue.
    
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
	
    NSValue *ptrValue = [NSValue valueWithPointer:spUser];
	SPUser *cachedUser = [self.userCache objectForKey:ptrValue];
    
    if (cachedUser != nil) {
        return cachedUser;
    }
	
	cachedUser = [[SPUser alloc] initWithUserStruct:spUser
										  inSession:self];
    
	if (cachedUser != nil)
		[self.userCache setObject:cachedUser forKey:ptrValue];
	
    return cachedUser;
}

-(SPPlaylist *)playlistForPlaylistStruct:(sp_playlist *)playlist {
    // WARNING: This MUST be called on the LibSpotify worker queue.
	
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
	
	NSValue *ptrValue = [NSValue valueWithPointer:playlist];
	SPPlaylist *cachedPlaylist = [playlistCache objectForKey:ptrValue];
	
	if (cachedPlaylist != nil) {
		return cachedPlaylist;
	}
    
	cachedPlaylist = [[SPPlaylist alloc] initWithPlaylistStruct:playlist
													  inSession:self];
	
	[playlistCache setObject:cachedPlaylist forKey:ptrValue];
	return cachedPlaylist;
}

-(SPPlaylistFolder *)playlistFolderForFolderId:(sp_uint64)playlistId inContainer:(SPPlaylistContainer *)aContainer {
	
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
	
	NSNumber *wrappedId = [NSNumber numberWithUnsignedLongLong:playlistId];
	SPPlaylistFolder *cachedPlaylistFolder = [playlistCache objectForKey:wrappedId];
	
	if (cachedPlaylistFolder != nil) {
		return cachedPlaylistFolder;
	}
	
	cachedPlaylistFolder = [[SPPlaylistFolder alloc] initWithPlaylistFolderId:playlistId
																	container:aContainer
																	inSession:self];
	
	[playlistCache setObject:cachedPlaylistFolder forKey:wrappedId];
	return cachedPlaylistFolder;
}

-(SPPlaylist *)unknownPlaylistForPlaylistStruct:(sp_playlist *)playlist {
	return (SPUnknownPlaylist*) [self playlistForPlaylistStruct:playlist];
}

-(void)trackForURL:(NSURL *)url callback:(void (^)(SPTrack *track))block {
	
	sp_linktype linkType = [url spotifyLinkType];
	
	if (!(linkType == SP_LINKTYPE_TRACK || linkType == SP_LINKTYPE_LOCALTRACK)) {
		if (block) block(nil);
		return;
	}
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		SPTrack *trackObj = nil;
		sp_link *link = [url createSpotifyLink];
		if (link != NULL) {
			sp_track *track = sp_link_as_track(link);
			sp_track_add_ref(track);
			trackObj = [self trackForTrackStruct:track];
			sp_track_release(track);
			sp_link_release(link);
		}
		
		if (block) dispatch_async(dispatch_get_main_queue(), ^() { block(trackObj); });
	});
}

-(void)userForURL:(NSURL *)url callback:(void (^)(SPUser *user))block {
	
	if ([url spotifyLinkType] != SP_LINKTYPE_PROFILE) {
		if (block) block(nil);
		return;
	}
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		SPUser *userObj = nil;
		sp_link *link = [url createSpotifyLink];
		if (link != NULL) {
			sp_user *aUser = sp_link_as_user(link);
			sp_user_add_ref(aUser);
			userObj = [self userForUserStruct:aUser];
			sp_link_release(link);
			sp_user_release(aUser);
		}
		
		if (block) dispatch_async(dispatch_get_main_queue(), ^() { block(userObj); });
	});
}

-(void)playlistForURL:(NSURL *)url callback:(void (^)(SPPlaylist *playlist))block {
	
	if ([url spotifyLinkType] != SP_LINKTYPE_PLAYLIST) {
		if (block) block(nil);
		return;
	}
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		SPPlaylist *playlist = nil;
		sp_link *link = [url createSpotifyLink];
		if (link != NULL) {
			sp_playlist *aPlaylist = sp_playlist_create(self.session, link);
			sp_link_release(link);
			playlist = [self playlistForPlaylistStruct:aPlaylist];            
			sp_playlist_release(aPlaylist); //TODO
		}
		
		if (block) dispatch_async(dispatch_get_main_queue(), ^() { block(playlist); });
	});
}

-(void)searchForURL:(NSURL *)url callback:(void (^)(SPSearch *search))block {
	if (block) block([SPSearch searchWithURL:url inSession:self]);
}

-(void)albumForURL:(NSURL *)url callback:(void (^)(SPAlbum *album))block {
	[SPAlbum albumWithAlbumURL:url inSession:self callback:block];
}

-(void)artistForURL:(NSURL *)url callback:(void (^)(SPArtist *artist))block {
	[SPArtist artistWithArtistURL:url inSession:self callback:block];
}

-(void)imageForURL:(NSURL *)url callback:(void (^)(SPImage *image))block {
	[SPImage imageWithImageURL:url inSession:self callback:block];
}

-(void)objectRepresentationForSpotifyURL:(NSURL *)aSpotifyUrlOfSomeKind callback:(void (^)(sp_linktype linkType, id objectRepresentation))block {
	
	if (aSpotifyUrlOfSomeKind == nil || block == nil) {
		if (block) block(SP_LINKTYPE_INVALID, nil);
		return;
	}
	
	__block sp_linktype linkType = [aSpotifyUrlOfSomeKind spotifyLinkType];
	
	if (linkType == SP_LINKTYPE_TRACK || linkType == SP_LINKTYPE_LOCALTRACK)
		[self trackForURL:aSpotifyUrlOfSomeKind callback:^(SPTrack *track) { block(linkType, track); }];
	
	else if (linkType == SP_LINKTYPE_ALBUM)
		[self albumForURL:aSpotifyUrlOfSomeKind callback:^(SPAlbum *album) { block(linkType, album); }];
	
	else if (linkType == SP_LINKTYPE_ARTIST)
		[self artistForURL:aSpotifyUrlOfSomeKind callback:^(SPArtist *artist) { block(linkType, artist); }];
	
	else if (linkType == SP_LINKTYPE_SEARCH)
		[self searchForURL:aSpotifyUrlOfSomeKind callback:^(SPSearch *search) { block(linkType, search); }];
	
	else if (linkType == SP_LINKTYPE_PLAYLIST)
		[self playlistForURL:aSpotifyUrlOfSomeKind callback:^(SPPlaylist *playlist) { block(linkType, playlist); }];
	
	else if (linkType == SP_LINKTYPE_PROFILE)
		[self userForURL:aSpotifyUrlOfSomeKind callback:^(SPUser *createdUser) { block(linkType, createdUser); }];
	
	else if (linkType == SP_LINKTYPE_STARRED)
		block(linkType, self.starredPlaylist);
	
	else if (linkType == SP_LINKTYPE_IMAGE)
		[self imageForURL:aSpotifyUrlOfSomeKind callback:^(SPImage *image) { block(linkType, image); }];
}

-(SPPostTracksToInboxOperation *)postTracks:(NSArray *)tracks 
                              toInboxOfUser:(NSString *)targetUserName
                                withMessage:(NSString *)aFriendlyMessage
                                   callback:(SPErrorableOperationCallback)block {
	
	return [[SPPostTracksToInboxOperation alloc] initBySendingTracks:tracks
															  toUser:targetUserName
															 message:aFriendlyMessage
														   inSession:self
															callback:block];	
}

-(void)addLoadingObject:(id)object;
{
	dispatch_async([SPSession libSpotifyQueue], ^{
		[self.loadingObjects addObject:object];
	});
}

-(void)checkLoadingObjects{
	
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
	
	//Let objects that got new metadata fire their KVO's
	NSMutableSet *objectsToRemove = [NSMutableSet set];
	
	for (id object in self.loadingObjects) {
		if ([object checkLoaded])
			[objectsToRemove addObject:object];
	}

	for (id object in objectsToRemove) {
		[self.loadingObjects removeObject:object];
	}
}

#pragma mark Properties

-(void)setPreferredBitrate:(sp_bitrate)bitrate {
    dispatch_async([SPSession libSpotifyQueue], ^() { if (self.session) sp_session_preferred_bitrate(self.session, bitrate); });
}

-(void)setMaximumCacheSizeMB:(size_t)maximumCacheSizeMB {
    dispatch_async([SPSession libSpotifyQueue], ^() { if (self.session) sp_session_set_cache_size(self.session, maximumCacheSizeMB); });
}

-(void)fetchOfflineKeyTimeRemaining:(void (^)(NSTimeInterval remainingTime))block {
	dispatch_async([SPSession libSpotifyQueue], ^() {
		NSTimeInterval interval = 0.0;
		if (self.session) interval = sp_offline_time_left(self.session);
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (block) block(interval);
		});
	});
}

@synthesize offlineStatistics;
@synthesize offlinePlaylistsRemaining;
@synthesize offlineTracksRemaining;
@synthesize offlineSyncing;

@synthesize delegate;
@synthesize playbackDelegate;
@synthesize audioDeliveryDelegate;
@synthesize session = _session;

-(sp_session *)session {
	
#if DEBUG 
	NSAssert(dispatch_get_current_queue() == [SPSession libSpotifyQueue], @"Not on correct queue!");
#endif
	return _session;
}

#pragma mark Playback

-(void)preloadTrackForPlayback:(SPTrack *)aTrack callback:(SPErrorableOperationCallback)block {
	
	dispatch_async([SPSession libSpotifyQueue], ^() {
		
		sp_error errorCode = SP_ERROR_TRACK_NOT_PLAYABLE;
		NSError *error = nil;
		
		if (aTrack != nil && self.session != NULL)
			errorCode = sp_session_player_prefetch(self.session, aTrack.track);
			
		if (errorCode != SP_ERROR_OK)
			error = [NSError spotifyErrorWithCode:errorCode];
			
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(error); });
	});
}

-(void)playTrack:(SPTrack *)aTrack callback:(SPErrorableOperationCallback)block {
	
	dispatch_async([SPSession libSpotifyQueue], ^() {
		
		sp_error errorCode = SP_ERROR_TRACK_NOT_PLAYABLE;
		NSError *error = nil;
		
		if (aTrack != nil && self.session != NULL)
			errorCode = sp_session_player_load(self.session, aTrack.track);
		
		if (errorCode == SP_ERROR_OK) {
			dispatch_async(dispatch_get_main_queue(), ^{ self.playing = YES; });
		} else {
			error = [NSError spotifyErrorWithCode:errorCode];
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{ if (block) block(error); });
	});
}

-(void)seekPlaybackToOffset:(NSTimeInterval)offset {
	dispatch_async([SPSession libSpotifyQueue], ^() { if (self.session != NULL) sp_session_player_seek(self.session, (int)offset * 1000); });
}

-(void)setPlaying:(BOOL)nowPlaying {
	dispatch_async([SPSession libSpotifyQueue], ^() { if (self.session) sp_session_player_play(self.session, nowPlaying); });
	_playing = nowPlaying;
}

-(BOOL)isPlaying {
	return _playing;
}

-(void)setUsingVolumeNormalization:(BOOL)usingVolumeNormalization {
#if TARGET_OS_IPHONE
	// No normalization on iOS yet :-(
	usingVolumeNormalization = NO;
#endif
	_cachedIsUsingNormalization = usingVolumeNormalization;
	dispatch_async([SPSession libSpotifyQueue], ^() { sp_session_set_volume_normalization(self.session, usingVolumeNormalization); });
}

-(BOOL)isUsingVolumeNormalization {
	return _cachedIsUsingNormalization;
}

-(void)unloadPlayback {
	self.playing = NO;
	dispatch_async([SPSession libSpotifyQueue], ^() { if (self.session) sp_session_player_unload(self.session); });
}


#pragma mark libSpotify Run Loop

-(void)prodSession {
    
    // Cancel previous delayed calls to this 
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:_cmd
                                               object:nil];
    
    int timeout = 0;
    sp_session_process_events(self.session, &timeout);
    
    [self performSelector:_cmd
               withObject:nil
               afterDelay:((double)timeout / 1000.0)];
    
}

#pragma mark -

-(void)dealloc {
	
	[self removeObserver:self forKeyPath:@"connectionState"];
	[self removeObserver:self forKeyPath:@"starredPlaylist.items"];
	
	sp_session *outgoing_session = _session;
	
	dispatch_async([SPSession libSpotifyQueue], ^{
		if (!outgoing_session) return;
		sp_session_player_unload(outgoing_session);
		sp_session_logout(outgoing_session);
	});
}

@end

