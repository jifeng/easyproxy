// Generated by CoffeeScript 1.9.0
var Proxy, clone, events, http, net, os, urllib, util, _defaultPath,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __hasProp = {}.hasOwnProperty;

net = require('net');

events = require('events');

urllib = require('url');

http = require('http');

util = require(__dirname + '/util');

clone = require('clone');

os = require('options-stream');

_defaultPath = function(targets) {
  return targets && targets[0] && targets[0].path;
};

Proxy = (function(_super) {
  __extends(Proxy, _super);

  function Proxy(options) {
    var routers;
    this.options = options || {};
    routers = this.options.routers || [];
    this.filters = [];
    this.map = {};
    this.apps = this.options.apps || [];
    this.specify();
    this.server = http.createServer();
    this.server.on('request', (function(_this) {
      return function(req, res) {
        var opt, proxy, router, _i, _len;
        for (_i = 0, _len = routers.length; _i < _len; _i++) {
          router = routers[_i];
          req.apps = res.apps = _this.apps;
          if (router.match && router.handle && router.match(req, res)) {
            return router.handle(req, res);
          }
        }
        opt = _this._requestOption(req, {
          connection: 'close'
        });
        if (opt.path === void 0) {
          if (_this.options.noHandler !== void 0) {
            return _this.options.noHandler(req, res);
          }
          res.statusCode = 404;
          return res.end('app is not registered' + JSON.stringify(opt.options));
        }
        proxy = http.request(opt.options, function(resProxy) {
          var k, v, _ref;
          res.setHeader('Server', (_this.options && _this.options.appname) || 'Easyproxy');
          if (_this.options.debug === true) {
            res.setHeader('HC-Socket', opt.options.socketPath);
          }
          res.statusCode = resProxy.statusCode;
          _ref = resProxy.headers;
          for (k in _ref) {
            v = _ref[k];
            res.setHeader(util.upHeaderKey(k), v);
          }
          return resProxy.pipe(res);
        });
        return req.pipe(proxy);
      };
    })(this));
    this.server.on('upgrade', (function(_this) {
      return function(req, socket, upgradeHead) {
        var opt, proxy;
        opt = _this._requestOption(req, true);
        if (opt.path === void 0) {
          return socket.end(util.status404Line);
        }
        opt.options.headers.Upgrade = 'websocket';
        proxy = http.request(opt.options);
        proxy.on('upgrade', function(res, proxySocket, upgradeHead) {
          var headers;
          headers = ['HTTP/1.1 101 Switching Protocols', 'Upgrade: websocket', 'Connection: Upgrade', 'Sec-WebSocket-Accept: ' + res.headers['sec-websocket-accept']];
          if (res.headers['sec-websocket-protocol']) {
            headers.push("Sec-Websocket-Protocol: " + res.headers['sec-websocket-protocol']);
          }
          headers = headers.concat('', '').join('\r\n');
          socket.write(headers);
          proxySocket.pipe(socket);
          return socket.pipe(proxySocket);
        });
        return req.pipe(proxy);
      };
    })(this));
  }

  Proxy.prototype.reload = function(apps) {
    this.apps = clone(apps);
    return this.specify();
  };

  Proxy.prototype.specify = function() {
    var app, apps, host, map, _i, _j, _len, _len1, _ref, _ref1;
    this.apps = this.apps || [];
    apps = [];
    _ref = this.apps;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      app = _ref[_i];
      if (app.status === 'on') {
        apps.push(app);
      }
    }
    this.app = apps;
    map = {};
    _ref1 = this.apps;
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      app = _ref1[_j];
      host = app.host && app.host.trim();
      if (map[host] === void 0) {
        map[host] = [app];
      } else {
        map[host].push(app);
      }
    }
    return this.map = map;
  };

  Proxy.prototype.register = function(app, cb) {
    var flag, prefix, target, targets, _i, _len;
    app = app || {};
    app.status = 'on';
    prefix = app.prefix || '';
    if (prefix[prefix.length - 1] !== '/') {
      prefix = prefix + '/';
    }
    app.prefix = prefix;
    targets = this._find({
      host: app.host,
      url: app.prefix
    });
    if (0 === targets.length) {
      this.apps.unshift(app);
      this.specify();
      return cb && cb();
    }
    flag = true;
    for (_i = 0, _len = targets.length; _i < _len; _i++) {
      target = targets[_i];
      if (app.path === target) {
        flag = false;
        break;
      }
    }
    if (flag === true) {
      this.apps.unshift(app);
    }
    this.specify();
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
    this.specify();
    return cb && cb();
  };

  Proxy.prototype.clear = function(cb) {
    this.apps = [];
    return cb && cb();
  };

  Proxy.prototype.clearFilters = function(cb) {
    this.filters = [];
    return cb && cb();
  };

  Proxy.prototype._find = function(head, apps) {
    var arr, i, item, len, prefix, targets, url, urlArr, value, _i, _j, _len, _len1;
    apps = apps || this.apps;
    targets = [];
    for (_i = 0, _len = apps.length; _i < _len; _i++) {
      value = apps[_i];
      if (value.status === 'on') {
        if (head.host.indexOf(value.host) === 0) {
          url = head.url;
          prefix = value.prefix;
          if (prefix.indexOf(':')) {
            arr = prefix.split('/');
            urlArr = url.split('/');
            for (i = _j = 0, _len1 = arr.length; _j < _len1; i = ++_j) {
              item = arr[i];
              if (0 === item.indexOf(':')) {
                arr[i] = urlArr[i] || arr[i];
              }
            }
            prefix = arr.join('/');
          }
          if (url.indexOf(prefix) === 0) {
            len = prefix.length;
            if (url.length === len || url[len - 1] === '/' || url[len - 1] === '') {
              targets.push(value);
            }
          }
        }
      }
    }
    return targets;
  };

  Proxy.prototype.find = function(head) {
    var apps, err, func, target, targets, _i, _len, _ref;
    apps = this.map[head.host] || [];
    targets = this._find(head, apps);
    try {
      _ref = this.filters;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        func = _ref[_i];
        if ('function' === typeof func) {
          target = func({
            targets: targets,
            request: head.request
          });
          if (target) {
            return target;
          }
        }
      }
    } catch (_error) {
      err = _error;
      console.log(err);
    }
    return _defaultPath(targets);
  };

  Proxy.prototype._requestOption = function(req, headersOptions) {
    var headers, host, ip, options, path, pathname, port, url, urlObj;
    ip = req.headers['x-forwarded-for'] || (req.connection && req.connection.remoteAddress) || (req.socket && req.socket.remoteAddress) || (req.connection && req.connection.socket && req.connection.socket.remoteAddress);
    port = req.headers['x-forwarded-for-port'] || (req.connection && req.connection.remotePort) || (req.socket && req.socket.remotePort) || (req.connection && req.connection.socket && req.connection.socket.remotePort);
    url = req.url;
    urlObj = urllib.parse(url);
    pathname = urlObj.pathname;
    if (pathname[pathname.length - 1] !== '/') {
      pathname = pathname + '/';
    }
    headers = req.headers || {};
    host = headers.host;
    headers['X-Forwarded-For'] = headers['X-Forwarded-For'] || ip;
    headers['X-Forwarded-For-Port'] = headers['X-Forwarded-For-Port'] || port;
    headers = os(headers, headersOptions);
    if (host.indexOf(':') > 0) {
      host = host.split(':')[0];
    }
    path = this.find({
      url: pathname,
      host: host,
      headers: headers,
      request: req
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

  Proxy.prototype.bindFilter = function(func, cb) {
    this.filters.unshift(func);
    return cb && cb();
  };

  Proxy.prototype.close = function(cb) {
    return this.server.close(cb);
  };

  return Proxy;

})(events.EventEmitter);

module.exports = function(options) {
  return new Proxy(options);
};
