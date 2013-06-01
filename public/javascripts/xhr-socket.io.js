/** Socket.IO 0.6 - Built with build.js */
/**
 * Socket.IO client
 * 
 * @author Guillermo Rauch <guillermo@learnboost.com>
 * @license The MIT license.
 * @copyright Copyright (c) 2010 LearnBoost <dev@learnboost.com>
 */

this.io = {
	version: '0.6',
	
	setPath: function(path){
		if (window.console && console.error) console.error('io.setPath will be removed. Please set the variable WEB_SOCKET_SWF_LOCATION pointing to WebSocketMain.swf');
		this.path = /\/$/.test(path) ? path : path + '/';
		WEB_SOCKET_SWF_LOCATION = path + 'lib/vendor/web-socket-js/WebSocketMain.swf';
	}
};

if ('jQuery' in this) jQuery.io = this.io;

if (typeof window != 'undefined'){
  // WEB_SOCKET_SWF_LOCATION = (document.location.protocol == 'https:' ? 'https:' : 'http:') + '//cdn.socket.io/' + this.io.version + '/WebSocketMain.swf';
  WEB_SOCKET_SWF_LOCATION = '/socket.io/lib/vendor/web-socket-js/WebSocketMain.swf';
}
/**
 * Socket.IO client
 * 
 * @author Guillermo Rauch <guillermo@learnboost.com>
 * @license The MIT license.
 * @copyright Copyright (c) 2010 LearnBoost <dev@learnboost.com>
 */

(function(){

	var _pageLoaded = false;

	io.util = {

		ios: false,

		load: function(fn){
			if (document.readyState == 'complete' || _pageLoaded) return fn();
			if ('attachEvent' in window){
				window.attachEvent('onload', fn);
			} else {
				window.addEventListener('load', fn, false);
			}
		},

		inherit: function(ctor, superCtor){
			// no support for `instanceof` for now
			for (var i in superCtor.prototype){
				ctor.prototype[i] = superCtor.prototype[i];
			}
		},

		indexOf: function(arr, item, from){
			for (var l = arr.length, i = (from < 0) ? Math.max(0, l + from) : from || 0; i < l; i++){
				if (arr[i] === item) return i;
			}
			return -1;
		},

		isArray: function(obj){
			return Object.prototype.toString.call(obj) === '[object Array]';
		},
		
    merge: function(target, additional){
      for (var i in additional)
        if (additional.hasOwnProperty(i))
          target[i] = additional[i];
    }

	};

	io.util.ios = /iphone|ipad/i.test(navigator.userAgent);
	io.util.android = /android/i.test(navigator.userAgent);
	io.util.opera = /opera/i.test(navigator.userAgent);

	io.util.load(function(){
		_pageLoaded = true;
	});

})();
/**
 * Socket.IO client
 * 
 * @author Guillermo Rauch <guillermo@learnboost.com>
 * @license The MIT license.
 * @copyright Copyright (c) 2010 LearnBoost <dev@learnboost.com>
 */

// abstract

(function(){
	
	var frame = '~m~',
	
	stringify = function(message){
		if (Object.prototype.toString.call(message) == '[object Object]'){
			if (!('JSON' in window)){
				if ('console' in window && console.error) console.error('Trying to encode as JSON, but JSON.stringify is missing.');
				return '{ "$error": "Invalid message" }';
			}
			return '~j~' + JSON.stringify(message);
		} else {
			return String(message);
		}
	};
	
	Transport = io.Transport = function(base, options){
		this.base = base;
		this.options = {
			timeout: 15000 // based on heartbeat interval default
		};
		io.util.merge(this.options, options);
	};

	Transport.prototype.send = function(){
		throw new Error('Missing send() implementation');
	};

	Transport.prototype.connect = function(){
		throw new Error('Missing connect() implementation');
	};

	Transport.prototype.disconnect = function(){
		throw new Error('Missing disconnect() implementation');
	};
	
	Transport.prototype._encode = function(messages){
		var ret = '', message,
				messages = io.util.isArray(messages) ? messages : [messages];
		for (var i = 0, l = messages.length; i < l; i++){
			message = messages[i] === null || messages[i] === undefined ? '' : stringify(messages[i]);
			ret += frame + message.length + frame + message;
		}
		return ret;
	};
	
	Transport.prototype._decode = function(data){
		var messages = [], number, n;
		do {
			if (data.substr(0, 3) !== frame) return messages;
			data = data.substr(3);
			number = '', n = '';
			for (var i = 0, l = data.length; i < l; i++){
				n = Number(data.substr(i, 1));
				if (data.substr(i, 1) == n){
					number += n;
				} else {	
					data = data.substr(number.length + frame.length);
					number = Number(number);
					break;
				} 
			}
			messages.push(data.substr(0, number)); // here
			data = data.substr(number);
		} while(data !== '');
		return messages;
	};
	
	Transport.prototype._onData = function(data){
		this._setTimeout();
		var msgs = this._decode(data);
		if (msgs && msgs.length){
			for (var i = 0, l = msgs.length; i < l; i++){
				this._onMessage(msgs[i]);
			}
		}
	};
	
	Transport.prototype._setTimeout = function(){
		var self = this;
		if (this._timeout) clearTimeout(this._timeout);
		this._timeout = setTimeout(function(){
			self._onTimeout();
		}, this.options.timeout);
	};
	
	Transport.prototype._onTimeout = function(){
		this._onDisconnect();
	};
	
	Transport.prototype._onMessage = function(message){
		if (!this.sessionid){
			this.sessionid = message;
			this._onConnect();
		} else if (message.substr(0, 3) == '~h~'){
			this._onHeartbeat(message.substr(3));
		} else if (message.substr(0, 3) == '~j~'){
			this.base._onMessage(JSON.parse(message.substr(3)));
		} else {
			this.base._onMessage(message);
		}
	},
	
	Transport.prototype._onHeartbeat = function(heartbeat){
		this.send('~h~' + heartbeat); // echo
	};
	
	Transport.prototype._onConnect = function(){
		this.connected = true;
		this.connecting = false;
		this.base._onConnect();
		this._setTimeout();
	};

	Transport.prototype._onDisconnect = function(){
		this.connecting = false;
		this.connected = false;
		this.sessionid = null;
		this.base._onDisconnect();
	};

	Transport.prototype._prepareUrl = function(){
		return (this.base.options.secure ? 'https' : 'http') 
			+ '://' + this.base.host 
			+ ':' + this.base.options.port
			+ '/' + this.base.options.resource
			+ '/' + this.type
			+ (this.sessionid ? ('/' + this.sessionid) : '/');
	};

})();

/**
 * Socket.IO client
 * 
 * @author Guillermo Rauch <guillermo@learnboost.com>
 * @license The MIT license.
 * @copyright Copyright (c) 2010 LearnBoost <dev@learnboost.com>
 */

(function(){

	var empty = new Function(),

	XHRPolling = io.Transport['xhr-polling'] = function(){
		io.Transport.XHR.apply(this, arguments);
	};

	io.util.inherit(XHRPolling, io.Transport.XHR);

	XHRPolling.prototype.type = 'xhr-polling';

	XHRPolling.prototype.connect = function(){
		if (io.util.ios || io.util.android){
			var self = this;
			io.util.load(function(){
				setTimeout(function(){
					io.Transport.XHR.prototype.connect.call(self);
				}, 10);
			});
		} else {
			io.Transport.XHR.prototype.connect.call(this);
		}
	};

	XHRPolling.prototype._get = function(){
		var self = this;
		this._xhr = this._request(+ new Date, 'GET');
		if ('onload' in this._xhr){
			this._xhr.onload = function(){
				self._onData(this.responseText);
				self._get();
			};
		} else {
			this._xhr.onreadystatechange = function(){
				var status;
				if (self._xhr.readyState == 4){
					self._xhr.onreadystatechange = empty;
					try { status = self._xhr.status; } catch(e){}
					if (status == 200){
						self._onData(self._xhr.responseText);
						self._get();
					} else {
						self._onDisconnect();
					}
				}
			};
		}
		this._xhr.send();
	};

	XHRPolling.check = function(){
		return io.Transport.XHR.check();
	};

	XHRPolling.xdomainCheck = function(){
		return io.Transport.XHR.xdomainCheck();
	};

})();