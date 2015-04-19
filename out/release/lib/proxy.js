// Generated by CoffeeScript 1.9.2
var Proxy, _defaultPath, clone, events, http, net, os, urllib, util,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty;

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

Proxy = (function(superClass) {
  extend(Proxy, superClass);

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
        var j, len1, opt, proxy, router;
        for (j = 0, len1 = routers.length; j < len1; j++) {
          router = routers[j];
          req.apps = res.apps = _this.apps;
          if (router.match && router.handle && router.match(req, res)) {
            return router.handle(req, res);
          }
        }
        opt = _this._requestOption(req);
        if (opt.path === void 0) {
          if (_this.options.noHandler !== void 0) {
            return _this.options.noHandler(req, res);
          }
          res.statusCode = 404;
          return res.end('app is not registered' + JSON.stringify(opt.options));
        }
        proxy = http.request(opt.options, function(resProxy) {
          var k, ref, v;
          res.setHeader('Server', (_this.options && _this.options.appname) || 'Easyproxy');
          if (_this.options.debug === true) {
            res.setHeader('HC-Socket', opt.options.socketPath);
          }
          res.statusCode = resProxy.statusCode;
          ref = resProxy.headers;
          for (k in ref) {
            v = ref[k];
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
        opt = _this._requestOption(req);
        if (opt.path === void 0) {
          return socket.end(util.status404Line);
        }
        opt.options.headers.Upgrade = 'websocket';
        proxy = http.request(opt.options);
        proxy.on('upgrade', function(res, proxySocket, upgradeHead) {
          var headers, headersTemp, name, value, wsHeader;
          headersTemp = {
            'upgrade': 'websocket',
            'connection': 'Upgrade'
          };
          headers = os(headersTemp, res.headers);
          wsHeader = "HTTP/1.1 101 Switching Protocols\n" + (((function() {
            var results;
            results = [];
            for (name in headers) {
              value = headers[name];
              results.push(name + ": " + value);
            }
            return results;
          })()).join('\r\n')) + "\n\n";
          socket.write(wsHeader);
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
    var app, apps, host, j, l, len1, len2, map, ref, ref1;
    this.apps = this.apps || [];
    apps = [];
    ref = this.apps;
    for (j = 0, len1 = ref.length; j < len1; j++) {
      app = ref[j];
      if (app.status === 'on') {
        apps.push(app);
      }
    }
    this.app = apps;
    map = {};
    ref1 = this.apps;
    for (l = 0, len2 = ref1.length; l < len2; l++) {
      app = ref1[l];
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
    var flag, j, len1, prefix, target, targets;
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
    for (j = 0, len1 = targets.length; j < len1; j++) {
      target = targets[j];
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
    var j, l, len1, len2, prefix, ref, ref1, value;
    if (typeof app === 'string') {
      ref = this.apps;
      for (j = 0, len1 = ref.length; j < len1; j++) {
        value = ref[j];
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
      ref1 = this.apps;
      for (l = 0, len2 = ref1.length; l < len2; l++) {
        value = ref1[l];
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
    var arr, i, item, j, l, len, len1, len2, prefix, targets, url, urlArr, value;
    apps = apps || this.apps;
    targets = [];
    for (j = 0, len1 = apps.length; j < len1; j++) {
      value = apps[j];
      if (value.status === 'on') {
        if (head.host.indexOf(value.host) === 0) {
          url = head.url;
          prefix = value.prefix;
          if (prefix.indexOf(':')) {
            arr = prefix.split('/');
            urlArr = url.split('/');
            for (i = l = 0, len2 = arr.length; l < len2; i = ++l) {
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
    var apps, err, func, j, len1, ref, target, targets;
    apps = this.map[head.host] || [];
    targets = this._find(head, apps);
    try {
      ref = this.filters;
      for (j = 0, len1 = ref.length; j < len1; j++) {
        func = ref[j];
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

  Proxy.prototype._requestOption = function(req) {
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
