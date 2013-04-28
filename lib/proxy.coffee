net      = require 'net'
events   = require 'events'
util     = require './util'


# apps: [{appname: '', host: '', path: '', prefix: ''}, ...]

status404Line = util.status404Line
getHead = util.getHead

class Proxy extends events.EventEmitter
  constructor : (options) ->
    @options = options || {}

    @apps = @options.apps || []
    @server = net.createServer (c) =>
      first = true
      socket = null
      c.on 'data', (data) =>
        header = getHead data
        if first is true and socket is null
          first = false
          path = @_find(header)
          # 模拟404返回
          if path is undefined
            c.write(new Buffer status404Line);
            return c.end()
          socket = net.connect path, () ->
            socket.pipe(c)
        socket.write(data) if socket isnt null 

      c.on 'end', () ->
        socket.end() if socket isnt null 

  # 注册应用
  # app: {appname: '', host: '', path: '', prefix: ''}
  register : (app, cb) ->
    flag = true
    app = app || {}
    for value in @apps
      flag = false if value.host is app.host and value.prefix is app.prefix and value.path is app.path
    app.status = 'on'
    @apps.push(app) if flag is true
    cb && cb()

  # 删除应用
  unregister: (app, cb) ->
    app = app || {}
    for value in @apps
      value.status = 'off' if value.host is app.host and value.prefix is app.prefix and value.path is app.path
    cb && cb()

  _find: (head) ->
    for value in @apps
      if value.status is 'on'
        #先域名,后后缀
        if head.host.indexOf(value.host) > 0 or head.url.indexOf(value.prefix) is 0
          return value.path

  listen : (port, cb) ->
    @server.listen(port, cb);

  close: ()->
    @server.close()

module.exports = (options) ->
  new Proxy options
