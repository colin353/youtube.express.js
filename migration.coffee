# ----------------------------------
# Migration
# ----------------------------------
# Here we run some "create table" 
# scripts to make sure that the db has
# at least something in it.

app = process.app
db 	= process.db

if app.get('database type') == 'mysql'
	# MySQL table creation.
	db.query "CREATE TABLE IF NOT EXISTS `videos` (
	  `id` int(11) NOT NULL AUTO_INCREMENT,
	  `video_code` varchar(64) NOT NULL,
	  `last_played` timestamp NULL DEFAULT NULL,
	  PRIMARY KEY (`id`)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 ;"

else 
	# Postgres table creation.
	db.query "create table if not exists videos (
		id SERIAL PRIMARY KEY,
		video_code varchar(40) NOT NULL,
		last_played timestamp DEFAULT NULL
	)"