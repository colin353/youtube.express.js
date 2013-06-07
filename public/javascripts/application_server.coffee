# ----------------------------------
# YouTube API connections
# ----------------------------------

# This function actually connects the
# existing SWF object to a video.

embedYoutube = ->
	swfobject.embedSWF("http://www.youtube.com/apiplayer?enablejsapi=1&playerapiid=ytplayer&version=3",
                       "ytplayer", size.x, size.y, "8", null, null, { allowScriptAccess: 'always'} , {id: playerID });

# When the document loads, load a video (blank)
$ ->
	embedYoutube()

# This function is called by the
# youtube flash object when it is
# ready to go.

@onYouTubePlayerReady = ->
	document.player = $('#'+playerID).get(0)
	document.player.playVideo()
	document.connectToServer()

# Connect the document hooks into the
# player functionality.

document.didSkipVideo = (video_code) ->
	document.player.loadVideoById video_code

document.didLoadVideo = (video_code) ->
	document.player.loadVideoById video_code

document.didSetVolume = (vol) ->
	document.player.setVolume vol

document.didPlayVideo = ->
	document.player.playVideo()

document.didPauseVideo = ->
	document.player.pauseVideo()

# This function is deprecated.

video_not_yet_started = ->
	switch document.player.getPlayerState()
		when 1,2,3,5
			return no
		else
			return yes