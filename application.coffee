# ----------------------
# Application.coffee
# ----------------------
# This actually runs the
# server for the application

# Start with module dependencies.

express	= require 'express'
routes	= require './routes'
user	= require './routes/user'
http	= require 'http'
path 	= require 'path'

app = express()

# Configuration parameters

app.set 'port', process.env.PORT || 3000
app.set 'database url', process.env.DATABASE_URL

if app.get 'database url'
	app.set 'mode', 'production' 
else
	app.set 'mode', 'development'

console.log 'Application started in ',app.get('mode'),'mode'

app.set	'views', __dirname + '/views'
app.set 'view engine', 'jade'

app.use express.favicon()
app.use express.logger('dev')
app.use express.bodyParser()
app.use express.methodOverride()

# Static content delivery method

app.use '/js', express.static(path.join(__dirname, 'public/javascripts'))
app.use '/css', express.static(path.join(__dirname, 'public/stylesheets'))

app.use app.router

if app.get('mode') == 'development'
	app.use express.errorHandler

app.get '/', routes.index
app.get '/client', routes.client
app.get '/server', routes.server

process.httpserverinstance = http.createServer(app).listen app.get('port'), ->
	console.log 'Express server started: listening on port ', app.get('port')

# Connect to the database

if app.get('mode') == 'production'
	console.log 'Attempting to connect to pg via ', app.get('database url')
	pg = require 'pg'
	db = new pg.Client app.get('database url')
else 
	console.log 'Attempting to connect to mysql via ', app.get('database url')
	mysql = require 'mysql'
	db = mysql.createConnection {
		host: 		'localhost',
		user: 		'root',
		password: 	'bitnami',
		database:	'video'
	}

process.db = db

# Perform migration, if necessary.

# Do socket.io connection setup.
require './sock'