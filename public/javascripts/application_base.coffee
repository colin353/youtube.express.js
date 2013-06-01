# ----------------------------------
# Config and setup
# ----------------------------------
# Config and setup parameters

socket_url = '/'
size = {x: 436, y: 356 }
playerID = 'ytplayer';
video_media = []
playing_video = null
socket = null

allLoaded = no


# ----------------------------------
# Sockets and connections
# ----------------------------------
# Here we connect to the socket 
# interface and relaying data, etc.

document.connectToServer = ->
	socket = io.connect socket_url

	socket.on 'play', (data) ->
		console.log "Play detected",data
		document.didPlayVideo()
		isPlaying()
 
	socket.on 'pause', (data) ->
		console.log "Pause detected",data
		document.didPauseVideo()
		isNoLongerPlaying()

	socket.on 'volume', (vol) ->
		console.log "Volume change detected ",vol
		document.volume.setVolume(vol)

	socket.on 'skipped', (video_code) ->
		console.log "Skip initiated on video ",video_code
		if playing_video.video_code == video_code
			document.didLoadVideo video_media[0].video.video_code
			playing_video = video_media[0].video
		else 
			console.log 'Skipped video actually not playing, so we are good'

	socket.on 'upcoming', (videos) ->
		console.log 'Got a new video list.'
		if(videos.length > 0 && video_not_yet_started())
			document.didSkipVideo videos[0].video_code;


		video_media = []
		$('.media-list').html(' ');	

		for v in videos.slice(1) 
			video_media.push new MediaInterfaceElement(v)

		playing_video = videos[0]

		setTimeout(renderUpcomingIfAvailable,200)

	document.join()

document.join = (party = 'default') ->
	socket.emit 'join', 'default'


document.play = ->
	socket.emit 'play', {}

document.didPlayVideo = ->
	console.log 'Playing.'

document.pause = ->
	socket.emit 'pause', {}

document.didPauseVideo = ->
	console.log 'Paused.'

document.didLoadVideo = ->
	console.log 'Video loaded.'

document.setVolume = (vol) ->
	socket.emit 'volume', vol

document.didSetVolume = (vol) ->
	console.log 'Volume set.'

document.update = ->
	socket.emit 'update', {}

document.skip  =  ->
	vid = playing_video 
	socket.emit 'skip', vid

document.didSkipVideo = ->
	console.log 'Skipped.'

renderUpcomingIfAvailable = ->
	all_loaded = yes
	for v in video_media
		if v.loaded == no
			all_loaded = no
			break
	
	$('.media-list').html(' ')

	if all_loaded
		for v in video_media
			v.insert()

		setTimeout(onAllReady(),300) if !allLoaded
	else 
		setTimeout(renderUpcomingIfAvailable,200)

# ----------------------------------
# MediaInterfaceElements
# ----------------------------------
# Here we make a model for the
# MediaInterfaceElements that we are 
# going to be using in the HTML.

class MediaInterfaceElement
	constructor: (video) ->
		@video = video
		me = @
		me.loaded = no
		$.get "https://gdata.youtube.com/feeds/api/videos/#{@video.video_code}?v=2&alt=json", (r) ->
			me.description = r.valueOf('media$group').entry.media$group.media$description.$t.substring(0,140)
			me.title = r.valueOf('media$group').entry.title.$t.substring(0,64)
			me.loaded = yes

	render: ->
		html = 	'<li class="media well"><a class="pull-left" href="#">'
		html += "<img class='media-object' style='width:100px' src='http://img.youtube.com/vi/#{@video.video_code}/hqdefault.jpg'></a>"
		html += "<div class='media-body'><h4 class='media-heading'>#{@title}</h4><div class='media'>"
		html += "#{@description}</div></div></li>"
		#console.log 'attempting to render: ', html
		html

	insert: ->
		$('.media-list').append @render()

class VolumeController
	constructor: ->
		@percent = 80
		@setVolume @percent

	setVolume: (percent) ->
		@percent = percent
		$('.volume-control').css('width', "#{@percent}%")
		document.didSetVolume @percent
		

volumeDetector = (e) ->
	x_o = @offsetLeft - @scrollLeft
	y_o = @offsetTop  - @scrollTop

	x = e.pageX - x_o
	y = e.pageY - y_o

	document.setVolume(x * 100 / $('.volume-container').width())

# ----------------------------------
# Startup animations and other stuff
# ----------------------------------
# Here we get other visual and aesthetic
# javascript, for example, animations.

isPlaying = ->
	$('.play-control').hide()
	$('.pause-control').show()

isNoLongerPlaying = ->
	$('.play-control').show()
	$('.pause-control').hide()

onAllReady = ->
	$('.bigblock').fadeOut('slow');
	document.volume = new VolumeController()

	allLoaded = yes

	$('.volume-container').click volumeDetector
	$('.pause-control').click document.pause
	$('.skip-control').click document.skip
	$('.play-control').click document.play

	