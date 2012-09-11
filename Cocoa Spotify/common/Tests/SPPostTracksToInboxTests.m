//
//  SPPostTracksToInboxTests.m
//  CocoaLibSpotify Mac Framework
//
//  Created by Daniel Kennett on 10/05/2012.
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

#import "SPPostTracksToInboxTests.h"
#import "SPSession.h"
#import "SPTrack.h"
#import "SPPostTracksToInboxOperation.h"

static NSString * const kTargetUserName = @"alana-test";
static NSString * const kOperationMessage = @"Hello from the CocoaLibSpotify test suite!";
static NSString * const kTrackToSendURI = @"spotify:track:3O0kOIdSdb3xQnjoi1AjRD";

@implementation SPPostTracksToInboxTests

-(void)testPostTracksToInbox {
	
	[SPTrack trackForTrackURL:[NSURL URLWithString:kTrackToSendURI] inSession:[SPSession sharedSession] callback:^(SPTrack *track) {
		
		SPTestAssert(track != nil, @"SPTrack returned nil for %@", kTrackToSendURI);
		
		[SPPostTracksToInboxOperation sendTracks:[NSArray arrayWithObject:track]
										  toUser:kTargetUserName
										  message:kOperationMessage
									   inSession:[SPSession sharedSession]
										callback:^(NSError *error) {
											SPTestAssert(error == nil, @"Post to inbox operation encountered error: %@", error);
											SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"Post tracks callback on wrong queue.");
											SPPassTest();
										}];
	}];
}

@end
