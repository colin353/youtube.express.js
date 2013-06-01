$ ->
	embedYoutube()

# This function is called by the
# youtube flash object when it is
# ready to go.

$ ->
	document.connectToServer()


# This function is deprecated.

video_not_yet_started = ->
	switch 1
		when 1,2,3,5
			return no
		else
			return yes