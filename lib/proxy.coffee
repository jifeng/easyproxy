net      = require 'net'
events   = require 'events'


# apps: [{appname: '', host: '', path: '', prefix: ''}, ...]

status404Line = 'HTTP/1.10x204040x20Not Found\r\n'
SPACE = 0x20   # ' '
COLON = 0x3a   # 58, :
NEWLINE = 0x0a # \n
ENTER = 0x0d   # \r

# 需要优化的地方
getHead = (data) ->
  start = 0
  lineStart = 0
  lineCount = 0
  header = {}
  firstLineCount = 0
  firstLineStart = 0
  for value, i in data
    # 换行 '\r\n'
    if value is  ENTER and data[i + 1] is NEWLINE
      if data[i + 2] is  ENTER and data[i + 3] is NEWLINE
        # \r\n\r\n Host header not found
        return
      lineCount++
      lineStart = i + 2
    else
      #GET / HTTP/1.1
      if lineCount is 0
        if value is SPACE
          if (++firstLineCount) is 2
            header.url = data.toString('ascii', firstLineStart + 1, i)
          firstLineStart = i
      #Host: www.work1.com:1723
      #Cache-Control: max-age=0
      else
        if value is COLON and data[i + 1] is SPACE
          key = data.toString('ascii', lineStart, i).toLowerCase();
          if key is 'host'
            for hk, hi in data[(i + 2)..]
              if hk is ENTER
                header[key] = data.toString('ascii', i + 2, i + 2 + hi).trim().toLowerCase();
                return header
          valueStart = i + 2

class Proxy extends events.EventEmitter
  constructor : (options) ->
    @options = options || {}

    @apps = @options.apps || []
    @server = net.createServer (c) =>
      first = true
      socket = undefined
      c.on 'data', (data) =>
        header = getHead data
        if first is true and socket is undefined
          first = false
          path = @_find(header)
          # 模拟404返回
          if path is undefined
            c.write(new Buffer status404Line);
            return c.end()
          socket = net.connect path, () ->
            socket.pipe(c)
        socket.write(data) if socket isnt undefined 

      c.on 'end', () ->
        socket.end() if socket isnt undefined 

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
