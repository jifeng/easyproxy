net      = require 'net'
events   = require 'events'
urllib   = require 'url'
http     = require 'http'
util     = require __dirname + '/util'

# apps: [{appname: '', host: '', path: '', prefix: ''}, ...]

class Proxy extends events.EventEmitter
  constructor : (options) ->
    @options = options || {}
    routers = @options.routers || []
    @apps = @options.apps || []
    @server = http.createServer()
    @server.on 'request', (req, res) =>
      for router in routers
        req.apps = res.apps = @apps
        return router.handle(req, res) if router.match && router.handle && router.match(req, res)
      opt =  @_requestOption(req)
      if opt.path is undefined
        if @options.noHandler isnt undefined
          return @options.noHandler req, res
        res.statusCode = 404
        return res.end('app is not registered' + JSON.stringify(opt.options))
      proxy = http.request opt.options, (resProxy)->
        res.setHeader('Server',  (@options && @options.appname) || 'Easyproxy')
        res.statusCode = resProxy.statusCode
        for k, v of resProxy.headers
          res.setHeader(util.upHeaderKey(k), v)
        resProxy.pipe res
      req.pipe proxy

    @server.on 'upgrade', (req, socket, upgradeHead) =>
      opt =  @_requestOption(req)
      if opt.path is undefined
        return socket.end(util.status404Line)

      opt.options.headers.Upgrade =  'websocket';
      proxy = http.request opt.options
      proxy.on 'upgrade', (res, proxySocket, upgradeHead)->
        headers = [
          'HTTP/1.1 101 Switching Protocols',
          'Upgrade: websocket',
          'Connection: Upgrade',
          'Sec-WebSocket-Accept: ' + res.headers['sec-websocket-accept']
        ];
        headers = headers.concat('', '').join('\r\n');
        socket.write headers
        proxySocket.pipe socket
        socket.pipe proxySocket

      req.pipe proxy

  # 注册应用
  # app: {appname: '', host: '', path: '', prefix: ''}
  register : (app, cb) ->
    app = app || {}
    app.status = 'on'
    prefix = app.prefix || '';
    prefix = prefix + '/' if  prefix[prefix.length - 1] isnt '/'
    app.prefix = prefix
    flag = @find({host: app.host, url: app.prefix})
    if flag is undefined
      @apps.unshift(app)
    else if app.path isnt flag
      @apps.unshift(app)
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
    target = []
    for value in @apps
      if value.status is 'on'
        #先域名,判断后缀
        if head.host.indexOf(value.host) is 0
          url = head.url
          if url.indexOf(value.prefix) is 0
            len = value.prefix.length

            if url.length is len or url[len - 1] is '/' or url[len - 1] is ''
              target.push value.path
              # return value.path
    target

  find: (head)->
    target = @_find(head);
    target && target[0]

  _requestOption: (req) ->
    url = req.url
    urlObj = urllib.parse url
    pathname = urlObj.pathname
    pathname = pathname + '/'  if pathname[pathname.length - 1] isnt '/'
    headers = req.headers
    host = headers.host

    # 如果直接设置成close,返回到游览器的Connection 也会设置成 close
    # headers.connection = 'close'
    if host.indexOf(':') > 0
      host = host.split(':')[0]
    path = @find({url: pathname, host: host})
    return {path: path, options: { url: pathname, host: host} } if !path 
    options = {
      socketPath: path,
      method: req.method,
      headers: headers,
      path: req.url
    }
    return { path: path, options: options }

  listen : (port, hostname, cb) ->
    @server.listen(port, hostname, cb);

  close: (cb)->
    @server.close(cb)

module.exports = (options) ->
  new Proxy options
