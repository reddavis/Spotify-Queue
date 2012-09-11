# Spotify Queue

## Overview

At Riot, we have a Servor (http://blog.riothq.com/do-this-do-that). Servor uses Applescript to communicate with Spotify. There's even an Applescript to play a track. 

Problem is, there's no way to queue a track. Either you interupt the current track or wait around for it to finish and then start your new track.

So I built Spotify Queue, a little menu bar app that can sit on Servor and manage our music.

What makes it cool though, is that it is scriptable:

### Queue a Track

```applescript
tell application "Spotify Queue"
  addTrack "spotify:track:3iPR2xFG7CTREJTNMSvw74"
end tell
```

### Play

```applescript
tell application "Spotify Queue"
  play
end tell
```

### Pause

```applescript
tell application "Spotify Queue"
  pause
end tell
```

### Note

To compile the app you will need to add your own appkey.c which you can get from Spotify developer site (once you've signed up).

## Download

Coming soon
