net      = require 'net'
events   = require 'events'
urllib   = require 'url'
http     = require 'http'
util     = require __dirname + '/util'


# apps: [{appname: '', host: '', path: '', prefix: ''}, ...]

class Proxy extends events.EventEmitter
  constructor : (options) ->
    @options = options || {}

    @apps = @options.apps || []
    @server = http.createServer (req, res) =>
      url = req.url
      urlObj = urllib.parse url
      pathname = urlObj.pathname
      pathname = pathname + '/'  if pathname[pathname.length - 1] isnt '/'
      headers = req.headers
      host = headers.host

      if host.indexOf(':') > 0
        host = host.split(':')[0]
      path = @_find({url: pathname, host: host})

      if path is undefined
        if @options.noHandler isnt undefined
          return @options.noHandler req, res
        res.statusCode = 404
        return res.end('app is not registered' + JSON.stringify({url: pathname, host: host}))

      headers = req.headers
      headers.connection = 'close'
      options = {
        socketPath: path,
        method: req.method,
        headers: headers,
        path: req.url
      }
      proxy = http.request options, (resProxy)->
        res.setHeader('Server',  (@options && @options.appname) || 'Easyproxy')
        for k, v of resProxy.headers
          res.setHeader(util.upHeaderKey(k), v)
        resProxy.pipe res
      req.pipe proxy

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

  listen : (port, hostname, cb) ->
    @server.listen(port, hostname, cb);

  close: (cb)->
    @server.close(cb)

module.exports = (options) ->
  new Proxy options
