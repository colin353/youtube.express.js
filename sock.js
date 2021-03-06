// Generated by CoffeeScript 1.6.2
var Party, Video, app, db, io, misc_sockets, parties;

io = require('socket.io');

io = io.listen(process.httpserverinstance);

db = process.db;

app = process.app;

io.configure(function() {
  io.set("transports", ["xhr-polling"]);
  io.set("polling duration", 10);
  return io.set('log level', 1);
});

parties = {};

misc_sockets = [];

Video = (function() {
  Video.get = function(callback) {
    var retval;

    retval = [];
    console.log('Querying for videos.');
    return db.query("select * from videos order by last_played is NULL desc, last_played asc limit 4", function(err, result) {
      var f, row, _i, _j, _len, _len1, _ref;

      if (err) {
        throw err;
      }
      if (app.get('database type') === 'mysql') {
        for (_i = 0, _len = result.length; _i < _len; _i++) {
          row = result[_i];
          retval.push(new Video(row.id));
          console.log('Collating video ', row.id);
        }
      } else {
        _ref = result.rows;
        for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
          row = _ref[_j];
          retval.push(new Video(row.id));
          console.log('Collating video ', row.id);
        }
      }
      f = function() {
        var loaded, v, _k, _len2;

        loaded = true;
        for (_k = 0, _len2 = retval.length; _k < _len2; _k++) {
          v = retval[_k];
          if (v.loaded === false) {
            loaded = false;
            break;
          }
        }
        if (loaded) {
          return callback(retval);
        } else {
          return setTimeout(f, 200);
        }
      };
      return setTimeout(f, 200);
    });
  };

  function Video(id, callback) {
    var me;

    if (id == null) {
      id = 0;
    }
    if (id !== 0) {
      this.id = id;
      this.loaded = false;
      me = this;
      if (app.get('database type') === 'mysql') {
        db.query("select * from videos where id = " + this.id, function(err, result) {
          if (err) {
            throw err;
          }
          me.last_played = result[0].last_played;
          me.video_code = result[0].video_code;
          me.loaded = true;
          if (callback != null) {
            return callback();
          }
        });
      } else {
        db.query("select * from videos where id = " + this.id, function(err, result) {
          if (err) {
            throw err;
          }
          me.last_played = result.rows[0].last_played;
          me.video_code = result.rows[0].video_code;
          me.loaded = true;
          if (callback != null) {
            return callback();
          }
        });
      }
      this.saved = true;
    } else {
      this.id = 0;
      this.saved = false;
    }
  }

  Video.prototype.save = function(callback) {
    var me;

    if (this.saved) {
      me = this;
      return db.query("update videos set video_code = '" + this.video_code + "' where id = " + this.id, function(err, result) {
        if (err) {
          throw err;
        }
        me.id = result.insertId;
        if (callback != null) {
          return callback();
        }
      });
    } else {
      db.query("insert into videos (video_code) values ('" + this.video_code + "')");
      this.saved = true;
      if (callback != null) {
        return callback();
      }
    }
  };

  Video.prototype.updatePlayedTime = function() {
    return db.query("update videos set last_played = NOW() where id = " + this.id);
  };

  return Video;

})();

Party = (function() {
  Party.prototype.partylog = function(message) {
    console.log('Party #', this.name, ' :: ', message);
    return true;
  };

  function Party(name) {
    console.log('Party initializing...');
    this.name = name;
    this.sockets = [];
    this.partylog("Let's get this party started!");
  }

  Party.prototype.massUpdate = function(me) {
    if (me == null) {
      me = this;
    }
    me.partylog('Conducting a mass update.');
    return Video.get(function(v) {
      var s, _i, _len, _ref, _results;

      _ref = me.sockets;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        s = _ref[_i];
        _results.push(s.emit('upcoming', v));
      }
      return _results;
    });
  };

  Party.prototype.join = function(socket) {
    this.sockets.push(socket);
    Video.get(function(v) {
      return socket.emit('upcoming', v);
    });
    socket.party = this;
    socket.on('end', function() {
      var i;

      this.party.partylog('a connection was closed');
      i = this.party.sockets.indexOf(socket);
      this.party.sockets.splice(i, 1);
      if (this.party.sockets.length === 0) {
        return delete parties[this.party.name];
      }
    });
    socket.on('play', function() {
      var s, _i, _len, _ref, _results;

      this.party.partylog("somebody says to play");
      _ref = this.party.sockets;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        s = _ref[_i];
        _results.push(s.emit('play', '0'));
      }
      return _results;
    });
    socket.on('pause', function() {
      var s, _i, _len, _ref, _results;

      this.party.partylog("Somebody says: pause");
      _ref = this.party.sockets;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        s = _ref[_i];
        _results.push(s.emit('pause', '0'));
      }
      return _results;
    });
    socket.on('skip', function(video) {
      var me, s, v, _i, _len, _ref, _results;

      this.party.partylog("Somebody voted to skip video ", video);
      me = this.party;
      v = new Video(video.id, function() {
        v.updatePlayedTime();
        return setTimeout(function() {
          return me.massUpdate(me);
        }, 500);
      });
      _ref = this.party.sockets;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        s = _ref[_i];
        _results.push(s.emit('skipped', video.video_code));
      }
      return _results;
    });
    socket.on('volume', function(volume) {
      var s, _i, _len, _ref, _results;

      this.party.partylog("Somebody changed volume to: ", volume);
      _ref = this.party.sockets;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        s = _ref[_i];
        _results.push(s.emit('volume', volume));
      }
      return _results;
    });
    socket.on('add', function(video) {
      var me, v;

      this.party.partylog("Somebody added new video ", video.video_code);
      v = new Video();
      v.video_code = video.video_code;
      me = this.party;
      v.save(function() {
        var s, _i, _len, _ref, _results;

        _ref = me.sockets;
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          s = _ref[_i];
          _results.push(s.emit('added', v));
        }
        return _results;
      });
      return setTimeout(function() {
        return me.massUpdate(me);
      }, 500);
    });
    return socket.on('update', function() {
      console.log("Recieved request for playlist update");
      return Video.get(function(v) {
        return socket.emit('upcoming', v);
      });
    });
  };

  return Party;

})();

io.sockets.on('connection', function(socket) {
  socket.connected = false;
  misc_sockets.push(socket);
  socket.on('join', function(party) {
    var i;

    console.log('Somebody is joining us...');
    if (!parties.hasOwnProperty(party)) {
      console.log('No party exists. Creating new party ', party);
      parties[party] = new Party(party);
    }
    parties[party].join(socket);
    i = misc_sockets.indexOf(socket);
    return misc_sockets.splice(i, 1);
  });
  return socket.on('end', function() {
    var i;

    i = misc_sockets.indexOf(socket);
    if (i !== -1) {
      return misc_sockets.splice(i, 1);
    }
  });
});
