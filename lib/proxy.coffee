net      = require 'net'
events   = require 'events'
util     = require './util'
urllib   = require 'url'


# apps: [{appname: '', host: '', path: '', prefix: ''}, ...]

status404Line = util.status404Line
getHead = util.getHead

class Proxy extends events.EventEmitter
  constructor : (options) ->
    @options = options || {}

    @apps = @options.apps || []
    @server = net.createServer (c) =>
      socket = null
      chunks = []
      flag = false
      c.on 'data', (data) =>
        if flag is false
          chunks.push data
          listBuffer = Buffer.concat chunks
          return if (util.checkHead(listBuffer)) is false 

        header = getHead listBuffer
        urlObj = urllib.parse header.url
        pathname = urlObj.pathname
        pathname = pathname + '/'  if pathname[pathname.length - 1] isnt '/'

        if socket is null and flag is false
          path = @_find({url: pathname, host: header.host})
          # 模拟404返回
          if path is undefined
            c.write(new Buffer status404Line)
            return c.end()
          socket = net.connect path, () ->
            socket.pipe(c)
          flag = true
          return socket.write listBuffer
      return socket.write(data) if socket isnt null and flag is true
      c.on 'end', () ->
        if socket isnt null
          socket.end()
          socket = null

  # 注册应用
  # app: {appname: '', host: '', path: '', prefix: ''}
  register : (app, cb) ->
    app = app || {}
    app.status = 'on'
    prefix = app.prefix || '';
    prefix = prefix + '/' if  prefix[prefix.length - 1] isnt '/'
    app.prefix = prefix
    flag = @_find({host: app.host, url: app.prefix})
    @apps.push(app) if flag is undefined
    cb && cb()

  # 删除应用
  unregister: (app, cb) ->
    if typeof app is 'string'
      for value in @apps
        value.status = 'off' if value.appname is app
    else
      app = app || {}
      prefix = app.prefix || ''
      prefix += '/' if prefix[prefix.length - 1] isnt '/'
      for value in @apps
        value.status = 'off' if value.host is app.host and value.prefix is prefix and value.path is app.path
    cb && cb()

  # 清除所有注册的应用
  clear: (cb) ->
    @apps = []
    cb && cb()

  _find: (head) ->
    for value in @apps
      if value.status is 'on'
        #先域名,判断后缀
        if head.host.indexOf(value.host) >= 0
          url = head.url
          if url.indexOf(value.prefix) is 0
            len = value.prefix.length

            if url.length is len or url[len - 1] is '/' or url[len - 1] is ''
              return value.path

  listen : (port, cb) ->
    @server.listen(port, cb);

  close: (cb)->
    @server.close(cb)

module.exports = (options) ->
  new Proxy options
