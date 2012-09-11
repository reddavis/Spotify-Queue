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

<script src="https://gist.github.com/3702516.js?file=gistfile1.applescript"></script>

### Pause

<script src="https://gist.github.com/3702526.js?file=gistfile1.applescript"></script>

### Note

To compile the app you will need to add your own appkey.c which you can get from Spotify developer site (once you've signed up).

## Download

Coming soon
