//
//  SPMetadataTests.m
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

#import "SPMetadataTests.h"
#import "SPArtist.h"
#import "SPAlbum.h"
#import "SPArtistBrowse.h"
#import "SPAlbumBrowse.h"
#import "SPTrack.h"
#import "SPImage.h"
#import "SPToplist.h"
#import "SPAsyncLoading.h"
#import "SPSession.h"

static NSString * const kArtistLoadingTestURI = @"spotify:artist:26dSoYclwsYLMAKD3tpOr4"; // Britney Spears
static NSString * const kArtistBrowseLoadingTestURI = @"spotify:artist:5zzrJD2jXrE9dZ1AklRFcL"; //KT Tunstall
static NSString * const kAlbumLoadingTestURI = @"spotify:album:50KUdiSuV2MmBmreFPl3PE"; // Barenaked Ladies Live
static NSString * const kAlbumBrowseLoadingTestURI = @"spotify:album:7IH5SRyEVemZWfhjYmWtT1"; //Wall-E Soundtrack
static NSString * const kTrackLoadingTestURI = @"spotify:track:5iIeIeH3LBSMK92cMIXrVD"; // Spotify Test Track

@implementation SPMetadataTests

-(void)testArtistMetadataLoading {
	
	[SPArtist artistWithArtistURL:[NSURL URLWithString:kArtistLoadingTestURI]
						inSession:[SPSession sharedSession]
						 callback:^(SPArtist *artist) {
							 
							 SPTestAssert(artist != nil, @"%@ returned nil artist", kArtistLoadingTestURI);
							 
							 [SPAsyncLoading waitUntilLoaded:artist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
								 SPTestAssert(notLoadedItems.count == 0, @"Artist loading timed out for %@", artist);
								 SPTestAssert(artist.name.length != 0, @"Artist has no name");
								 SPPassTest();
							 }];
						 }];
}

-(void)testAlbumMetadataLoading {
	
	[SPAlbum albumWithAlbumURL:[NSURL URLWithString:kAlbumLoadingTestURI]
					 inSession:[SPSession sharedSession]
					  callback:^(SPAlbum *album) {
						  
						  SPTestAssert(album != nil, @"%@ returned nil album", kAlbumLoadingTestURI);
						  
						  [SPAsyncLoading waitUntilLoaded:album timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
							  SPTestAssert(notLoadedItems.count == 0, @"Album loading timed out for %@", album);
							  SPTestAssert(album.name.length != 0, @"Album has no name");
							  SPTestAssert(album.artist != nil, @"Album has no artist");
							  SPPassTest();
						  }];
					  }];
}

-(void)testArtistBrowseMetadataLoading {
	
	[SPArtistBrowse browseArtistAtURL:[NSURL URLWithString:kArtistBrowseLoadingTestURI]
							inSession:[SPSession sharedSession]
								 type:SP_ARTISTBROWSE_NO_TRACKS
							 callback:^(SPArtistBrowse *artistBrowse) {
								 
								 SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"browseArtistAtURL callback on wrong queue.");
								 
								 [SPAsyncLoading waitUntilLoaded:artistBrowse timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
									 SPTestAssert(notLoadedItems.count == 0, @"ArtistBrowse loading timed out for %@", artistBrowse);
									 SPTestAssert(artistBrowse.loadError == nil, @"ArtistBrowse encountered load error: %@", artistBrowse.loadError);
									 SPTestAssert(artistBrowse.albums.count != 0, @"ArtistBrowse has no albums");
									 SPTestAssert(artistBrowse.topTracks.count != 0, @"ArtistBrowse has no top tracks");
									 SPPassTest();
								 }];
							 }];
}

-(void)testAlbumBrowseMetadataLoading {
	
	[SPAlbumBrowse browseAlbumAtURL:[NSURL URLWithString:kAlbumBrowseLoadingTestURI]
						  inSession:[SPSession sharedSession]
						   callback:^(SPAlbumBrowse *albumBrowse) {
							   
							   SPTestAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"browseAlbumAtURL callback on wrong queue.");
							   
							   [SPAsyncLoading waitUntilLoaded:albumBrowse timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
								   SPTestAssert(notLoadedItems.count == 0, @"AlbumBrowse loading timed out for %@", albumBrowse);
								   SPTestAssert(albumBrowse.loadError == nil, @"AlbumBrowse encountered load error: %@", albumBrowse.loadError);
								   SPTestAssert(albumBrowse.tracks.count != 0, @"AlbumBrowse has no tracks");
								   SPTestAssert(albumBrowse.artist != 0, @"AlbumBrowse has no artist");
								   SPPassTest();
							   }];
						   }];
}

-(void)testTrackMetadataLoading {
	
	[SPTrack trackForTrackURL:[NSURL URLWithString:kTrackLoadingTestURI]
					inSession:[SPSession sharedSession]
					 callback:^(SPTrack *track) {
						 
						 [SPAsyncLoading waitUntilLoaded:track timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
							 SPTestAssert(notLoadedItems.count == 0, @"Track loading timed out for %@", track);
							 SPTestAssert(track.artists.count != 0, @"Track has no artists");
							 SPTestAssert(track.album != nil, @"Track has no album");
							 SPTestAssert(track.name.length != 0, @"Track has no name");
							 SPPassTest();
						 }];
					 }];
}

-(void)testImageLoading {
	
	[SPAlbum albumWithAlbumURL:[NSURL URLWithString:kAlbumLoadingTestURI]
					 inSession:[SPSession sharedSession]
					  callback:^(SPAlbum *album) {
						  
						  SPTestAssert(album != nil, @"%@ returned nil album", kAlbumLoadingTestURI);
						  
						  [SPAsyncLoading waitUntilLoaded:album timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
							  SPTestAssert(notLoadedItems.count == 0, @"Album loading timed out for %@", album);
							
							  [SPAsyncLoading waitUntilLoaded:album.cover timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedCover, NSArray *notLoadedCover) {
								  SPTestAssert(notLoadedCover.count == 0, @"Cover loading timed out for %@", album.cover);
								  SPTestAssert(album.cover.image != nil, @"Cover is loaded but has no image");
								  SPPassTest();
							  }];
						  }];
					  }];
}

-(void)testUserTopListLoading {
	
	SPToplist *userToplist = [SPToplist toplistForCurrentUserInSession:[SPSession sharedSession]];
	
	[SPAsyncLoading waitUntilLoaded:userToplist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
		SPTestAssert(notLoadedItems.count == 0, @"TopList loading timed out for %@", userToplist);
		SPTestAssert(userToplist.loadError == nil, @"TopList encountered loading error: %@", userToplist.loadError);
		// User can disable publishing of parts of their toplist, so we can't depend on there being anything in it.
		SPPassTest();
	}];
	
}

-(void)testLocaleToplistLoading {
	
	SPToplist *localeToplist = [SPToplist toplistForLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"SE"] inSession:[SPSession sharedSession]];
	
	[SPAsyncLoading waitUntilLoaded:localeToplist timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
		SPTestAssert(notLoadedItems.count == 0, @"TopList loading timed out for %@", localeToplist);
		SPTestAssert(localeToplist.loadError == nil, @"TopList encountered loading error: %@", localeToplist.loadError);
		SPTestAssert(localeToplist.artists.count > 0, @"TopList has no artists");
		SPTestAssert(localeToplist.albums.count > 0, @"TopList has no albums");
		SPTestAssert(localeToplist.tracks.count > 0, @"TopList has no tracks");
		SPPassTest();
	}];
}



@end
