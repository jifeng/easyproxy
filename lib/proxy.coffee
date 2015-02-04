net      = require 'net'
events   = require 'events'
urllib   = require 'url'
http     = require 'http'
util     = require __dirname + '/util'
clone    = require 'clone'

_defaultPath = (targets)->
  targets && targets[0] && targets[0].path

# apps: [{appname: '', host: '', path: '', prefix: ''}, ...]
class Proxy extends events.EventEmitter
  constructor : (options) ->
    @options = options || {}
    routers = @options.routers || []
    @filters = []
    @map = {}
    @apps = @options.apps || []
    @specify()
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
      proxy = http.request opt.options, (resProxy)=>
        res.setHeader('Server',  (@options && @options.appname) || 'Easyproxy')
        res.setHeader('HC-Socket', opt.options.socketPath) if @options.debug is true
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
  
  #重新加载
  reload: (apps)->
    @apps = clone apps
    @specify()

  specify: ()->
    #删除已经下线注册应用
    @apps = @apps or []
    apps = []
    for app in @apps
      apps.push app if app.status is 'on'
    @app = apps
    
    map = {}
    for app in @apps
      host = app.host and app.host.trim()
      if map[host] is undefined
        map[host] = [ app ]
      else
        map[host].push app
    @map = map

  # 注册应用
  # app: {appname: '', host: '', path: '', prefix: ''}
  register : (app, cb) ->
    app = app || {}
    app.status = 'on'
    prefix = app.prefix || '';
    prefix = prefix + '/' if  prefix[prefix.length - 1] isnt '/'
    app.prefix = prefix
    targets = @_find({host: app.host, url: app.prefix})
    if 0 is targets.length
      @apps.unshift(app)
      @specify()
      return cb && cb()
    flag = true
    for target in targets
      if app.path is target
        flag = false
        break
    @apps.unshift(app) if flag is true
    @specify()
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
    @specify()
    cb && cb()

  # 清除所有注册的应用
  clear: (cb) ->
    @apps = []
    cb && cb()

  clearFilters:(cb) ->
    @filters = []
    cb && cb()

  _find: (head, apps) ->
    apps = apps or @apps
    targets = []
    for value in apps
      if value.status is 'on'
        #先域名,判断后缀
        if head.host.indexOf(value.host) is 0
          url = head.url
          prefix = value.prefix
          #模糊匹配
          if prefix.indexOf ':'
            arr = prefix.split '/'
            urlArr = url.split '/'
            for item, i in arr
              arr[i] = urlArr[i] or arr[i] if 0 is item.indexOf ':'
            prefix = arr.join '/'

          if url.indexOf(prefix) is 0
            len = prefix.length
            if url.length is len or url[len - 1] is '/' or url[len - 1] is ''
              targets.push value
    targets

  
  find: (head)->
    apps = @map[head.host] or []
    targets = @_find(head, apps)
    try
      for func in @filters
        if 'function' is typeof func
          target = func({ targets: targets, request: head.request })
          return target if target
    catch err
      console.log(err)
    return _defaultPath(targets)

  _requestOption: (req) ->
    ip = req.headers['x-forwarded-for'] or  
     (req.connection and req.connection.remoteAddress) or 
     (req.socket and req.socket.remoteAddress) or
     (req.connection and req.connection.socket and req.connection.socket.remoteAddress)
    
    port = req.headers['x-forwarded-for-port'] or  
     (req.connection and req.connection.remotePort) or 
     (req.socket and req.socket.remotePort) or
     (req.connection and req.connection.socket and req.connection.socket.remotePort)
    

    url = req.url
    urlObj = urllib.parse url
    pathname = urlObj.pathname
    pathname = pathname + '/'  if pathname[pathname.length - 1] isnt '/'
    headers = req.headers || {}
    host = headers.host
    headers['X-Forwarded-For'] = headers['X-Forwarded-For'] || ip
    headers['X-Forwarded-For-Port'] = headers['X-Forwarded-For-Port'] or port
    # 如果直接设置成close,返回到游览器的Connection 也会设置成 close
    # headers.connection = 'close'
    if host.indexOf(':') > 0
      host = host.split(':')[0]
    path = @find({url: pathname, host: host, headers: headers, request: req})
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

  bindFilter: (func, cb)->
    @filters.unshift func
    cb && cb();

  close: (cb)->
    @server.close(cb)

module.exports = (options) ->
  new Proxy options
