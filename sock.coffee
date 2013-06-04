# ----------------------------------
# Socket IO
# ----------------------------------
# Here we do the socket IO interface
# for the clients. We distribute video
# codes, do updates, broadcast messages
# etc.

io = require 'socket.io'
io = io.listen(process.httpserverinstance)

# Database has already been setup. Use it from here.
db  = process.db
app = process.app

# Use long-polling.
io.configure ->
  io.set("transports", ["xhr-polling"])
  io.set("polling duration", 10)
  io.set('log level', 1)

parties = { }
misc_sockets = []

class Video 
	# Static methods:

	@get: (callback) ->
		retval = [];

		console.log 'Querying for videos.'

		db.query "select * from videos order by last_played is NULL desc, last_played asc limit 4", (err, result) ->
			throw err if err
			if app.get('database type') == 'mysql'
				# MySQL
				for row in result
					retval.push new Video(row.id)
					console.log 'Collating video ',row.id
			else 
				# PSQL
				for row in result.rows
					retval.push new Video(row.id)
					console.log 'Collating video ',row.id

			f = ->
				loaded = yes
				for v in retval
					if v.loaded == no
						loaded = no
						break

				if loaded
					callback(retval)
				else
					setTimeout(f,200)

			setTimeout(f,200)

	# Object-bound methods

	constructor: (id = 0, callback) ->
		if id != 0
			# Then the user must have provided an ID to load from
			@id = id
			@loaded = false
			me = @

			if app.get('database type') == 'mysql'	
				# MySQL
				db.query "select * from videos where id = #{@id}", (err, result) ->
					throw err if err
					me.last_played 	= result[0].last_played
					me.video_code	= result[0].video_code
					me.loaded 		= yes
					callback() if callback?
			else
				# PSQL
				db.query "select * from videos where id = #{@id}", (err, result) ->
					throw err if err
					me.last_played 	= result.rows[0].last_played
					me.video_code	= result.rows[0].video_code
					me.loaded 		= yes
					callback() if callback?

			@saved = yes
		else
			# Then the user must want to make a new one.
			@id = 0
			@saved = no

	save: (callback) ->
		if @saved
			me = @
			db.query "update videos set video_code = '#{@video_code}' where id = #{@id}", (err, result) ->
				throw err if err
				me.id = result.insertId
				callback() if callback?
		else
			db.query "insert into videos (video_code) values ('#{@video_code}')"
			@saved = yes
			callback() if callback?

	updatePlayedTime: ->
		db.query "update videos set last_played = NOW() where id = #{@id}"


class Party 
	partylog: (message) ->
		console.log 'Party #',@name,' :: ',message
		yes

	constructor: (name) ->
		console.log 'Party initializing...'
		@name = name
		@sockets = []
		@partylog "Let's get this party started!"

	massUpdate: (me = @) ->
		# This gets called by callbacks, so may
		# need to check for me in scope.

		me.partylog 'Conducting a mass update.'
		Video.get (v) ->
			for s in me.sockets
				s.emit 'upcoming', v

	join: (socket) ->
		# Add the socket to the list of sockets in the party.
		@sockets.push socket
		# Give it a list of upcoming videos automatically.
		Video.get (v) ->
			socket.emit 'upcoming', v

		socket.party = @

		socket.on 'end', ->
			# When a socket is terminated, remove
			# from the listening array.
			@party.partylog 'a connection was closed'
			i = @party.sockets.indexOf socket
			@party.sockets.splice i,1
			# If nobody is left in the party, kill it.
			if @party.sockets.length == 0
				delete parties[@party.name]

		socket.on 'play', ->
			# When somebody says play video
			@party.partylog "somebody says to play"
			# Tell everyone that the play event is on
			for s in @party.sockets
				s.emit 'play', '0'

		socket.on 'pause', ->
			# When somebody says pause video
			@party.partylog "Somebody says: pause"
			# Tell everyone that the pause event is on
			for s in @party.sockets
				s.emit 'pause', '0'

		socket.on 'skip', (video) ->
			@party.partylog "Somebody voted to skip video ",video
			# When somebody wants to skip the video
			me = @party
			v = new Video video.id, ->
				v.updatePlayedTime()
				setTimeout ->
					me.massUpdate(me)
				, 500
			# Tell everyone that a skip event occurred
			for s in @party.sockets
				s.emit 'skipped', video.video_code

		socket.on 'volume', (volume) ->
			# When somebody says pause video
			@party.partylog "Somebody changed volume to: ", volume
			# Tell everyone so their controllers can update
			for s in @party.sockets
				s.emit 'volume', volume

		socket.on 'add', (video) ->
			# When somebody says add a new video
			@party.partylog "Somebody added new video ", video.video_code

			v = new Video()
			v.video_code = video.video_code
			me = @party
			v.save ->
				for s in me.sockets
					s.emit 'added', v
			# Push a mass-update in half a second.
			setTimeout ->
				me.massUpdate(me)
			,500

		socket.on 'update', ->
			console.log "Recieved request for playlist update"
			Video.get (v) ->
				socket.emit 'upcoming', v


io.sockets.on 'connection', (socket) ->
	socket.connected = no

	misc_sockets.push socket

	socket.on 'join', (party) ->
		console.log 'Somebody is joining us...'
		# Does the party exist? If not, create a new one
		if !parties.hasOwnProperty party
			console.log 'No party exists. Creating new party ',party
			parties[party] = new Party(party);
		# Shift the socket to the targeted party.
		parties[party].join socket
		# Remove the socket from the misc category
		i = misc_sockets.indexOf socket
		misc_sockets.splice i,1

	socket.on 'end', ->
		# When a socket is terminated, remove
		# from the listening array.
		i = misc_sockets.indexOf socket
		misc_sockets.splice i,1 if i != -1

