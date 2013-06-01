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

if process.env.DATABASE_URL?
	app.set 'mode', 'production' 
else
	app.set 'mode', 'development'

app.set 'port', 3000
app.set 'port', process.env.PORT if app.get('mode') == 'production'


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
	console.log 'Starting application in production mode.'
	pg = require 'pg'
	db = new pg.Client process.env.DATABASE_URL
else 
	console.log 'Starting application in development mode.'
	mysql = require 'mysql'
	db = mysql.createConnection {
		host: 		'localhost',
		user: 		'root',
		password: 	'bitnami',
		database:	'video'
	}

process.db = db

# Do socket.io connection setup.
require './sock'