//
//  Guess_The_IntroViewController.m
//  Guess The Intro
//
//  Created by Daniel Kennett on 10/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Guess_The_IntroViewController.h"
#import "SPArrayExtensions.h"
#import <QuartzCore/QuartzCore.h>

static NSUInteger const kLoadingTimeout = 10;
static NSTimeInterval const kRoundDuration = 20.0;
static NSTimeInterval const kGameDuration = 60 * 5; // 5 mins
static NSTimeInterval const kGameCountdownThreshold = 30.0;

@interface Guess_The_IntroViewController ()
-(NSString *)stringFromScore:(NSInteger)aScore;
@end

@implementation Guess_The_IntroViewController

@synthesize multiplierLabel;
@synthesize currentScoreLabel;
@synthesize highScoreLabel;
@synthesize roundProgressIndicator;
@synthesize currentRoundScoreLabel;
@synthesize isLoadingView;
@synthesize countdownLabel;
@synthesize track1Button;
@synthesize track1TitleLabel;
@synthesize track2ArtistLabel;
@synthesize track3Button;
@synthesize track3TitleLabel;
@synthesize track3ArtistLabel;
@synthesize track4Button;
@synthesize track4TitleLabel;
@synthesize track4ArtistLabel;
@synthesize track1ArtistLabel;
@synthesize track2Button;
@synthesize track2TitleLabel;

@synthesize playbackManager;
@synthesize playlist;

@synthesize firstSuggestion;
@synthesize secondSuggestion;
@synthesize thirdSuggestion;
@synthesize fourthSuggestion;

@synthesize canPushOne;
@synthesize canPushTwo;
@synthesize canPushThree;
@synthesize canPushFour;

@synthesize userTopList;
@synthesize regionTopList;

@synthesize multiplier;
@synthesize score;
@synthesize roundStartDate;
@synthesize gameStartDate;
@synthesize trackPool;
@synthesize roundTimer;

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

-(NSString *)stringFromScore:(NSInteger)aScore {
	return [formatter stringFromNumber:[NSNumber numberWithInteger:aScore]];
}

#pragma mark - View lifecycle


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.track1Button.layer.borderColor = [UIColor darkGrayColor].CGColor;
	self.track1Button.layer.borderWidth = 1.0;
	
	self.track2Button.layer.borderColor = [UIColor darkGrayColor].CGColor;
	self.track2Button.layer.borderWidth = 1.0;
	
	self.track3Button.layer.borderColor = [UIColor darkGrayColor].CGColor;
	self.track3Button.layer.borderWidth = 1.0;
	
	self.track4Button.layer.borderColor = [UIColor darkGrayColor].CGColor;
	self.track4Button.layer.borderWidth = 1.0;
	
	formatter = [[NSNumberFormatter alloc] init];
	formatter.numberStyle = NSNumberFormatterDecimalStyle;
	
	self.multiplier = 1;
	self.highScoreLabel.text = [NSString stringWithFormat:@"High Score: %@", [self stringFromScore:[[NSUserDefaults standardUserDefaults] integerForKey:@"highScore"]]];
		
	[self addObserver:self forKeyPath:@"firstSuggestion.name" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"firstSuggestion.artists" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"firstSuggestion.album.cover.image" options:NSKeyValueObservingOptionInitial context:nil];
	
	[self addObserver:self forKeyPath:@"secondSuggestion.name" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"secondSuggestion.artists" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"secondSuggestion.album.cover.image" options:NSKeyValueObservingOptionInitial context:nil];
	
	[self addObserver:self forKeyPath:@"thirdSuggestion.name" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"thirdSuggestion.artists" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"thirdSuggestion.album.cover.image" options:NSKeyValueObservingOptionInitial context:nil];
	
	[self addObserver:self forKeyPath:@"fourthSuggestion.name" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"fourthSuggestion.artists" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"fourthSuggestion.album.cover.image" options:NSKeyValueObservingOptionInitial context:nil];
	
	[self addObserver:self forKeyPath:@"canPushOne" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"canPushTwo" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"canPushThree" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"canPushFour" options:NSKeyValueObservingOptionInitial context:nil];
	
	[self addObserver:self forKeyPath:@"currentRoundScore" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"roundTimeRemaining" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"gameTimeRemaining" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"score" options:NSKeyValueObservingOptionInitial context:nil];
	[self addObserver:self forKeyPath:@"multiplier" options:NSKeyValueObservingOptionInitial context:nil];
}

- (void)viewDidUnload
{
    [self setCurrentScoreLabel:nil];
    [self setMultiplierLabel:nil];
    [self setHighScoreLabel:nil];
    [self setTrack1Button:nil];
    [self setTrack1TitleLabel:nil];
    [self setTrack2ArtistLabel:nil];
    [self setTrack1ArtistLabel:nil];
    [self setTrack2Button:nil];
    [self setTrack2TitleLabel:nil];
    [self setTrack3Button:nil];
    [self setTrack3TitleLabel:nil];
    [self setTrack3ArtistLabel:nil];
    [self setTrack4Button:nil];
    [self setTrack4TitleLabel:nil];
    [self setTrack4ArtistLabel:nil];
    [self setRoundProgressIndicator:nil];
    [self setCurrentRoundScoreLabel:nil];
	[self setIsLoadingView:nil];
	[self setCountdownLabel:nil];
	
	[self removeObserver:self forKeyPath:@"firstSuggestion.name"];
	[self removeObserver:self forKeyPath:@"firstSuggestion.artists"];
	[self removeObserver:self forKeyPath:@"firstSuggestion.album.cover.image"];
	
	[self removeObserver:self forKeyPath:@"secondSuggestion.name"];
	[self removeObserver:self forKeyPath:@"secondSuggestion.artists"];
	[self removeObserver:self forKeyPath:@"secondSuggestion.album.cover.image"];
	
	[self removeObserver:self forKeyPath:@"thirdSuggestion.name"];
	[self removeObserver:self forKeyPath:@"thirdSuggestion.artists"];
	[self removeObserver:self forKeyPath:@"thirdSuggestion.album.cover.image"];
	
	[self removeObserver:self forKeyPath:@"fourthSuggestion.name"];
	[self removeObserver:self forKeyPath:@"fourthSuggestion.artists"];
	[self removeObserver:self forKeyPath:@"fourthSuggestion.album.cover.image"];
	
	[self removeObserver:self forKeyPath:@"canPushOne"];
	[self removeObserver:self forKeyPath:@"canPushTwo"];
	[self removeObserver:self forKeyPath:@"canPushThree"];
	[self removeObserver:self forKeyPath:@"canPushFour"];
	
	[self removeObserver:self forKeyPath:@"currentRoundScore"];
	[self removeObserver:self forKeyPath:@"roundTimeRemaining"];
	[self removeObserver:self forKeyPath:@"gameTimeRemaining"];
	[self removeObserver:self forKeyPath:@"score"];
	[self removeObserver:self forKeyPath:@"multiplier"];

	
	formatter = nil;

    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath hasPrefix:@"firstSuggestion"]) {
		[self.track1Button setImage:self.firstSuggestion.album.cover.image 
						   forState:UIControlStateNormal];
		self.track1ArtistLabel.text = [[self.firstSuggestion.artists valueForKey:@"name"] componentsJoinedByString:@", "];
		self.track1TitleLabel.text = self.firstSuggestion.name;
		
	} else if ([keyPath hasPrefix:@"secondSuggestion"]) {
		[self.track2Button setImage:self.secondSuggestion.album.cover.image 
						   forState:UIControlStateNormal];
		self.track2ArtistLabel.text = [[self.secondSuggestion.artists valueForKey:@"name"] componentsJoinedByString:@", "];
		self.track2TitleLabel.text = self.secondSuggestion.name;
		
	} else if ([keyPath hasPrefix:@"thirdSuggestion"]) {
		[self.track3Button setImage:self.thirdSuggestion.album.cover.image 
						   forState:UIControlStateNormal];
		self.track3ArtistLabel.text = [[self.thirdSuggestion.artists valueForKey:@"name"] componentsJoinedByString:@", "];
		self.track3TitleLabel.text = self.thirdSuggestion.name;
		
	} else if ([keyPath hasPrefix:@"fourthSuggestion"]) {
		[self.track4Button setImage:self.fourthSuggestion.album.cover.image 
						   forState:UIControlStateNormal];
		self.track4ArtistLabel.text = [[self.fourthSuggestion.artists valueForKey:@"name"] componentsJoinedByString:@", "];
		self.track4TitleLabel.text = self.fourthSuggestion.name;
		
	} else if ([keyPath hasPrefix:@"canPush"]) {
		self.track1Button.enabled = self.canPushOne;
		self.track2Button.enabled = self.canPushTwo;
		self.track3Button.enabled = self.canPushThree;
		self.track4Button.enabled = self.canPushFour;
		
	} else if ([keyPath isEqualToString:@"currentRoundScore"]) {
		self.currentRoundScoreLabel.text = [self stringFromScore:self.currentRoundScore];
		
	} else if ([keyPath isEqualToString:@"roundTimeRemaining"]) {
		self.roundProgressIndicator.progress = self.roundTimeRemaining / kRoundDuration;
		
	} else if ([keyPath isEqualToString:@"score"]) {
		self.currentScoreLabel.text = [self stringFromScore:self.score];
		
	} else if ([keyPath isEqualToString:@"multiplier"]) {
		self.multiplierLabel.text = [NSString stringWithFormat:@"%@x (Highest: %@x)", [NSNumber numberWithUnsignedInteger:self.multiplier], [[NSUserDefaults standardUserDefaults] valueForKey:@"highMultiplier"]];
		
	} else if ([keyPath isEqualToString:@"gameTimeRemaining"]) {
		
		if (![self hideCountdown] && self.countdownLabel.hidden)
			self.countdownLabel.hidden = NO;
		else if ([self hideCountdown] && !self.countdownLabel.hidden)
			self.countdownLabel.hidden = YES;
		
		if (!self.countdownLabel.hidden)
			self.countdownLabel.text = [NSString stringWithFormat:@"%1.0f", self.gameTimeRemaining];
		
	} else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -
#pragma mark SPLoginViewController Delegate

-(void)loginViewController:(SPLoginViewController *)controller didCompleteSuccessfully:(BOOL)didLogin {
	
	[self dismissModalViewControllerAnimated:YES];
	
	self.roundProgressIndicator.hidden = YES;
	self.isLoadingView.hidden = !self.roundProgressIndicator.hidden;
	
	self.regionTopList = [SPToplist toplistForLocale:[SPSession sharedSession].locale
										   inSession:[SPSession sharedSession]];
	self.userTopList = [SPToplist toplistForCurrentUserInSession:[SPSession sharedSession]];
	
	//if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CreatePlaylist"])
	//	self.playlist = [[[SPSession sharedSession] userPlaylists] createPlaylistWithName:self.playlistNameField.stringValue];
	
	[self waitAndFillTrackPool];
}

#pragma mark -
#pragma mark SPSession Delegates

-(void)sessionDidLoginSuccessfully:(SPSession *)aSession; {
	// Invoked by SPSession after a successful login.
}

-(void)session:(SPSession *)aSession didFailToLoginWithError:(NSError *)error; {
    
	// Invoked by SPSession after a failed login.
	// Forward to login view
    if ([self.modalViewController respondsToSelector:@selector(session:didFailToLoginWithError:)])
		[self.modalViewController performSelector:@selector(session:didFailToLoginWithError:) withObject:aSession withObject:error];
}

-(void)sessionDidLogOut:(SPSession *)aSession; {}
-(void)session:(SPSession *)aSession didEncounterNetworkError:(NSError *)error; {}
-(void)session:(SPSession *)aSession didLogMessage:(NSString *)aMessage; {}
-(void)sessionDidChangeMetadata:(SPSession *)aSession; {}

-(void)session:(SPSession *)aSession recievedMessageForUser:(NSString *)aMessage; {
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Message from Spotify"
													message:aMessage
												   delegate:nil
										  cancelButtonTitle:@"OK"
										  otherButtonTitles:nil];
	[alert show];
}

#pragma mark -
#pragma mark Game UI Actions

- (IBAction)guessOne:(id)sender {
	
	self.canPushOne = NO;
	[self guessTrack:self.firstSuggestion];
}

- (IBAction)guessTwo:(id)sender {
	
	self.canPushTwo = NO;
	[self guessTrack:self.secondSuggestion];
}

- (IBAction)guessThree:(id)sender {
	
	self.canPushThree = NO;
	[self guessTrack:self.thirdSuggestion];
}

- (IBAction)guessFour:(id)sender {
	
	self.canPushFour = NO;
	[self guessTrack:self.fourthSuggestion];
}

#pragma mark -
#pragma mark Finding Tracks

-(void)waitAndFillTrackPool {
	
	[SPAsyncLoading waitUntilLoaded:[SPSession sharedSession] timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedession, NSArray *notLoadedSession) {
		
		// The session is logged in and loaded — now wait for the userPlaylists to load.
		NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), @"Session loaded.");
		
		[SPAsyncLoading waitUntilLoaded:[SPSession sharedSession].userPlaylists timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedContainers, NSArray *notLoadedContainers) {
			
			// User playlists are loaded — wait for playlists to load their metadata.
			NSLog(@"[%@ %@]: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), @"Container loaded.");
			
			NSMutableArray *playlists = [NSMutableArray array];
			[playlists addObject:[SPSession sharedSession].starredPlaylist];
			[playlists addObject:[SPSession sharedSession].inboxPlaylist];
			[playlists addObjectsFromArray:[SPSession sharedSession].userPlaylists.flattenedPlaylists];
			
			[SPAsyncLoading waitUntilLoaded:playlists timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedPlaylists, NSArray *notLoadedPlaylists) {
				
				// All of our playlists have loaded their metadata — wait for all tracks to load their metadata.
				NSLog(@"[%@ %@]: %@ of %@ playlists loaded.", NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
					  [NSNumber numberWithInteger:loadedPlaylists.count], [NSNumber numberWithInteger:loadedPlaylists.count + notLoadedPlaylists.count]);
				
				NSArray *playlistItems = [loadedPlaylists valueForKeyPath:@"@unionOfArrays.items"];
				NSArray *tracks = [self tracksFromPlaylistItems:playlistItems];
				
				[SPAsyncLoading waitUntilLoaded:tracks timeout:kSPAsyncLoadingDefaultTimeout then:^(NSArray *loadedTracks, NSArray *notLoadedTracks) {
					
					// All of our tracks have loaded their metadata. Hooray!
					NSLog(@"[%@ %@]: %@ of %@ tracks loaded.", NSStringFromClass([self class]), NSStringFromSelector(_cmd), 
						  [NSNumber numberWithInteger:loadedTracks.count], [NSNumber numberWithInteger:loadedTracks.count + notLoadedTracks.count]);
					
					NSMutableArray *theTrackPool = [NSMutableArray arrayWithCapacity:loadedTracks.count];
					
					for (SPTrack *aTrack in loadedTracks) {
						if (aTrack.availability == SP_TRACK_AVAILABILITY_AVAILABLE && [aTrack.name length] > 0)
							[theTrackPool addObject:aTrack];
					}
					
					self.trackPool = [NSMutableArray arrayWithArray:[[NSSet setWithArray:theTrackPool] allObjects]];
					// ^ Thin out duplicates.
					
					[self startNewRound];
					
				}];
			}];
		}];
	}];
}

-(NSArray *)playlistsInFolder:(SPPlaylistFolder *)aFolder {
	
	NSMutableArray *playlists = [NSMutableArray arrayWithCapacity:[[aFolder playlists] count]];
	
	for (id playlistOrFolder in aFolder.playlists) {
		if ([playlistOrFolder isKindOfClass:[SPPlaylist class]]) {
			[playlists addObject:playlistOrFolder];
		} else {
			[playlists addObjectsFromArray:[self playlistsInFolder:playlistOrFolder]];
		}
	}
	return [NSArray arrayWithArray:playlists];
}

-(NSArray *)tracksFromPlaylistItems:(NSArray *)items {
	
	NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:items.count];
	
	for (SPPlaylistItem *anItem in items) {
		if (anItem.itemClass == [SPTrack class]) {
			[tracks addObject:anItem.item];
		}
	}
	
	return [NSArray arrayWithArray:tracks];
}

-(SPTrack *)trackForUserToGuessWithAlternativeOne:(SPTrack **)alternative two:(SPTrack **)anotherAlternative three:(SPTrack **)aThirdAlternative {
	
	SPTrack *theOne = nil;
	while ((!theOne.availability == SP_TRACK_AVAILABILITY_AVAILABLE) && theOne.duration < kRoundDuration) {
		theOne = [self.trackPool randomObject];
		[self.trackPool removeObject:theOne];
		
		if ([self.trackPool count] < 3) {
			// Eeek! Can't fill alternatives!
			if (alternative != NULL)
				*alternative = nil;
			if (anotherAlternative != NULL)
				*anotherAlternative = nil;
			if (aThirdAlternative != NULL)
				*aThirdAlternative = nil;
			
			return nil;
		}
	}	
	
	// Make sure we don't choose the same one more than once
	
	if (alternative != NULL) {
		*alternative = [self.trackPool randomObject];
		[self.trackPool removeObject:*alternative];
	}
	if (anotherAlternative != NULL) {
		*anotherAlternative = [self.trackPool randomObject];
		[self.trackPool removeObject:*anotherAlternative];
	}
	if (aThirdAlternative != NULL) {
		*aThirdAlternative = [self.trackPool randomObject];
		[self.trackPool removeObject:*aThirdAlternative];
	}
	
	if (alternative != NULL)
		[self.trackPool addObject:*alternative];
	if (anotherAlternative != NULL)
		[self.trackPool addObject:*anotherAlternative];
	if (aThirdAlternative != NULL)
		[self.trackPool addObject:*aThirdAlternative];
	
	return theOne;
}

#pragma mark -
#pragma mark Game Logic


-(NSTimeInterval)gameTimeRemaining {
	if (self.gameStartDate == nil)
		return 0.0;
	return kGameDuration -[[NSDate date] timeIntervalSinceDate:self.gameStartDate];
}

-(NSTimeInterval)roundTimeRemaining {
	if (self.roundStartDate == nil)
		return 0.0;
	return kRoundDuration -[[NSDate date] timeIntervalSinceDate:self.roundStartDate];
}

-(NSUInteger)currentRoundScore {
	if (self.roundStartDate == nil)
		return 0.0;
	NSTimeInterval remainingTime = [self roundTimeRemaining];
	return MAX(remainingTime * remainingTime * self.multiplier, 1.0);
}

+(NSSet *)keyPathsForValuesAffectingHideCountdown {
	return [NSSet setWithObject:@"gameTimeRemaining"];
}

-(BOOL)hideCountdown {
	return (self.gameStartDate == nil || self.gameTimeRemaining > kGameCountdownThreshold);
}

#pragma mark -

-(void)roundTimerDidTick:(NSTimer *)aTimer {
	
	if (self.roundTimeRemaining <= 0.0)
		[self roundTimeExpired];
	
	if (self.gameTimeRemaining <= 0.0)
		[self gameOverWithReason:@"Out of time!"];
	
	[self willChangeValueForKey:@"roundTimeRemaining"];
	[self didChangeValueForKey:@"roundTimeRemaining"];
	[self willChangeValueForKey:@"gameTimeRemaining"];
	[self didChangeValueForKey:@"gameTimeRemaining"];
	[self willChangeValueForKey:@"currentRoundScore"];
	[self didChangeValueForKey:@"currentRoundScore"];
}

-(void)roundTimeExpired {
	//NSBeep();
	self.multiplier = 1;
	[self startNewRound];
}

#pragma mark -

-(void)guessTrack:(SPTrack *)itsTotallyThisOne {
	
	if (self.playbackManager.currentTrack == nil || itsTotallyThisOne == nil)
		return;
	
	if (itsTotallyThisOne == self.playbackManager.currentTrack) {
		self.score += self.currentRoundScore;
		
		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"highScore"] < self.score) {
			[[NSUserDefaults standardUserDefaults] setInteger:self.score forKey:@"highScore"];
			self.highScoreLabel.text = [NSString stringWithFormat:@"High Score: %@", [self stringFromScore:[[NSUserDefaults standardUserDefaults] integerForKey:@"highScore"]]];
		}		
		
		if ([[NSUserDefaults standardUserDefaults] integerForKey:@"highMultiplier"] < (self.multiplier + 1))
			[[NSUserDefaults standardUserDefaults] setInteger:(self .multiplier + 1) forKey:@"highMultiplier"];
		
		self.multiplier++;
		
		[self startNewRound];
	} else {
		//NSBeep();
		self.multiplier = 1;
		self.roundStartDate = [NSDate dateWithTimeInterval:-(kRoundDuration / 4) sinceDate:self.roundStartDate];
	}
}

-(void)startNewRound {
	
	if (self.playbackManager.currentTrack != nil) {
		[self.playlist addItem:self.playbackManager.currentTrack atIndex:self.playlist.items.count callback:^(NSError *error) {
			if (error) NSLog(@"%@", error);
		}];
	}
	
	// Starting a new round means resetting, selecting tracks then starting the timer again 
	// when the audio starts playing.
	
	self.playbackManager.isPlaying = NO;
	self.firstSuggestion = nil;
	self.secondSuggestion = nil;
	self.thirdSuggestion = nil;
	self.fourthSuggestion = nil;
	self.roundStartDate = nil;
	
	self.roundProgressIndicator.hidden = YES;
	self.isLoadingView.hidden = !self.roundProgressIndicator.hidden;
	
	[self.roundTimer invalidate];
	self.roundTimer = nil;
	
	SPTrack *one = nil;
	SPTrack *two = nil;
	SPTrack *three = nil;
	SPTrack *theOne = [self trackForUserToGuessWithAlternativeOne:&one two:&two three:&three];
	
	if (theOne != nil) {
		
		NSMutableArray *array = [NSMutableArray arrayWithObjects:theOne, one, two, three, nil];
		self.firstSuggestion = [array randomObject];
		[array removeObject:self.firstSuggestion];
		self.secondSuggestion = [array randomObject];
		[array removeObject:self.secondSuggestion];
		self.thirdSuggestion = [array randomObject];
		[array removeObject:self.thirdSuggestion];
		self.fourthSuggestion = [array randomObject];
		[array removeObject:self.fourthSuggestion];
		
		// Force loading of images.
		UIImage *im =self.firstSuggestion.album.cover.image;
		im = self.secondSuggestion.album.cover.image;
		im = self.thirdSuggestion.album.cover.image;
		im = self.fourthSuggestion.album.cover.image;
		
		//Disable buttons until playback starts
		self.canPushOne = NO;
		self.canPushTwo = NO;
		self.canPushThree = NO;
		self.canPushFour = NO;
		
		[self startPlaybackOfTrack:theOne];
		
	} else {
		
		[self gameOverWithReason:@"Out of tracks!"];
	}
}

-(void)gameOverWithReason:(NSString *)reason {
	
	self.playbackManager.isPlaying = NO;
	self.firstSuggestion = nil;
	self.secondSuggestion = nil;
	self.thirdSuggestion = nil;
	self.fourthSuggestion = nil;
	self.roundStartDate = nil;
	self.gameStartDate = nil;
	
	self.roundProgressIndicator.hidden = YES;
	self.isLoadingView.hidden = !self.roundProgressIndicator.hidden;
	
	[self.roundTimer invalidate];
	self.roundTimer = nil;
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:reason
													message:[NSString stringWithFormat:@"You scored %@ points!", 
															 [self stringFromScore:self.score]]
												   delegate:self
										  cancelButtonTitle:@"Again!"
										  otherButtonTitles:nil];
	[alert show];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	self.score = 0;
	self.multiplier = 1;
	[self waitAndFillTrackPool];
}

#pragma mark -
#pragma mark Playback

- (void)startPlaybackOfTrack:(SPTrack *)aTrack {
	
	[SPAsyncLoading waitUntilLoaded:aTrack timeout:5.0 then:^(NSArray *loadedItems, NSArray *notLoadedItems) {
		[self.playbackManager playTrack:aTrack callback:^(NSError *error) {
			
			if (!error) return;
			
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Couldn't Play"
															message:error.localizedDescription
														   delegate:self
												  cancelButtonTitle:@"OK"
												  otherButtonTitles:nil];
			[alert show];
		}];
	}];
}

-(void)playbackManagerWillStartPlayingAudio:(SPPlaybackManager *)aPlaybackManager {
	
	self.roundProgressIndicator.hidden = NO;
	self.isLoadingView.hidden = !self.roundProgressIndicator.hidden;
	
	self.roundStartDate = [NSDate date];
	if (self.gameStartDate == nil)
		self.gameStartDate = roundStartDate;
	
	self.roundTimer = [NSTimer scheduledTimerWithTimeInterval:0.05
													   target:self
													 selector:@selector(roundTimerDidTick:)
													 userInfo:nil
													  repeats:YES];
	
	self.canPushOne = YES;
	self.canPushTwo = YES;
	self.canPushThree = YES;
	self.canPushFour = YES;
	
}


- (void)dealloc {
	
	[roundTimer invalidate];
	
}

@end
