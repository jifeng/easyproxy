// Generated by CoffeeScript 1.6.2
var Proxy, events, getHead, net, status404Line, urllib, util,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

net = require('net');

events = require('events');

util = require('./util');

urllib = require('url');

status404Line = util.status404Line;

getHead = util.getHead;

Proxy = (function(_super) {
  __extends(Proxy, _super);

  function Proxy(options) {
    var _this = this;

    this.options = options || {};
    this.apps = this.options.apps || [];
    this.server = net.createServer(function(c) {
      var chunks, flag, socket;

      socket = null;
      chunks = [];
      flag = false;
      c.on('data', function(data) {
        var header, listBuffer, path, pathname, urlObj;

        if (flag === false) {
          chunks.push(data);
          listBuffer = Buffer.concat(chunks);
          if ((util.checkHead(listBuffer)) === false) {
            return;
          }
        }
        header = getHead(listBuffer);
        urlObj = urllib.parse(header.url);
        pathname = urlObj.pathname;
        if (pathname[pathname.length - 1] !== '/') {
          pathname = pathname + '/';
        }
        if (socket === null && flag === false) {
          path = _this._find({
            url: pathname,
            host: header.host
          });
          if (path === void 0) {
            c.write(new Buffer(status404Line));
            return c.end();
          }
          socket = net.connect(path, function() {
            return socket.pipe(c);
          });
          flag = true;
          return socket.write(listBuffer);
        }
      });
      if (socket !== null && flag === true) {
        return socket.write(data);
      }
      return c.on('end', function() {
        if (socket !== null) {
          socket.end();
          return socket = null;
        }
      });
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
    var value, _i, _len, _ref;

    app = app || {};
    _ref = this.apps;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      value = _ref[_i];
      if (value.host === app.host && value.prefix === app.prefix && value.path === app.path) {
        value.status = 'off';
      }
    }
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

  Proxy.prototype.listen = function(port, cb) {
    return this.server.listen(port, cb);
  };

  Proxy.prototype.close = function() {
    return this.server.close();
  };

  return Proxy;

})(events.EventEmitter);

module.exports = function(options) {
  return new Proxy(options);
};
