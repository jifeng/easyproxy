// Generated by CoffeeScript 1.6.3
var Proxy, events, http, net, urllib, util,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

net = require('net');

events = require('events');

urllib = require('url');

http = require('http');

util = require(__dirname + '/util');

Proxy = (function(_super) {
  __extends(Proxy, _super);

  function Proxy(options) {
    var _this = this;
    this.options = options || {};
    this.apps = this.options.apps || [];
    this.server = http.createServer();
    this.server.on('request', function(req, res) {
      var opt, proxy;
      opt = _this._requestOption(req);
      if (opt.path === void 0) {
        if (_this.options.noHandler !== void 0) {
          return _this.options.noHandler(req, res);
        }
        res.statusCode = 404;
        return res.end('app is not registered' + JSON.stringify(opt.options));
      }
      proxy = http.request(opt.options, function(resProxy) {
        var k, v, _ref;
        res.setHeader('Server', (this.options && this.options.appname) || 'Easyproxy');
        _ref = resProxy.headers;
        for (k in _ref) {
          v = _ref[k];
          res.setHeader(util.upHeaderKey(k), v);
        }
        return resProxy.pipe(res);
      });
      return req.pipe(proxy);
    });
    this.server.on('upgrade', function(req, socket, upgradeHead) {
      var opt, proxy;
      opt = _this._requestOption(req);
      if (opt.path === void 0) {
        return socket.end(util.status404Line);
      }
      opt.options.headers.Upgrade = 'websocket';
      proxy = http.request(opt.options);
      proxy.on('upgrade', function(res, proxySocket, upgradeHead) {
        var headers;
        headers = ['HTTP/1.1 101 Switching Protocols', 'Upgrade: websocket', 'Connection: Upgrade', 'Sec-WebSocket-Accept: ' + res.headers['sec-websocket-accept']];
        headers = headers.concat('', '').join('\r\n');
        socket.write(headers);
        proxySocket.pipe(socket);
        return socket.pipe(proxySocket);
      });
      return req.pipe(proxy);
    });
  }

  Proxy.prototype.register = function(app, cb) {
    var flag, prefix;
    app = app || {};
    app.status = 'on';
    prefix = app.prefix || '';
    if (prefix[prefix.length - 1] !== '/') {
      prefix = prefix + '/';
    }
    app.prefix = prefix;
    flag = this._find({
      host: app.host,
      url: app.prefix
    });
    if (flag === void 0) {
      this.apps.push(app);
    }
    return cb && cb();
  };

  Proxy.prototype.unregister = function(app, cb) {
    var prefix, value, _i, _j, _len, _len1, _ref, _ref1;
    if (typeof app === 'string') {
      _ref = this.apps;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        value = _ref[_i];
        if (value.appname === app) {
          value.status = 'off';
        }
      }
    } else {
      app = app || {};
      prefix = app.prefix || '';
      if (prefix[prefix.length - 1] !== '/') {
        prefix += '/';
      }
      _ref1 = this.apps;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        value = _ref1[_j];
        if (value.host === app.host && value.prefix === prefix && value.path === app.path) {
          value.status = 'off';
        }
      }
    }
    return cb && cb();
  };

  Proxy.prototype.clear = function(cb) {
    this.apps = [];
    return cb && cb();
  };

  Proxy.prototype._find = function(head) {
    var len, url, value, _i, _len, _ref;
    _ref = this.apps;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      value = _ref[_i];
      if (value.status === 'on') {
        if (head.host.indexOf(value.host) >= 0) {
          url = head.url;
          if (url.indexOf(value.prefix) === 0) {
            len = value.prefix.length;
            if (url.length === len || url[len - 1] === '/' || url[len - 1] === '') {
              return value.path;
            }
          }
        }
      }
    }
  };

  Proxy.prototype._requestOption = function(req) {
    var headers, host, options, path, pathname, url, urlObj;
    url = req.url;
    urlObj = urllib.parse(url);
    pathname = urlObj.pathname;
    if (pathname[pathname.length - 1] !== '/') {
      pathname = pathname + '/';
    }
    headers = req.headers;
    host = headers.host;
    if (host.indexOf(':') > 0) {
      host = host.split(':')[0];
    }
    path = this._find({
      url: pathname,
      host: host
    });
    if (!path) {
      return {
        path: path,
        options: {
          url: pathname,
          host: host
        }
      };
    }
    options = {
      socketPath: path,
      method: req.method,
      headers: headers,
      path: req.url
    };
    return {
      path: path,
      options: options
    };
  };

  Proxy.prototype.listen = function(port, hostname, cb) {
    return this.server.listen(port, hostname, cb);
  };

  Proxy.prototype.close = function(cb) {
    return this.server.close(cb);
  };

  return Proxy;

})(events.EventEmitter);

module.exports = function(options) {
  return new Proxy(options);
};
