# websocket协议 反向代理 单元测试
# easyproxy - tests/test-websocket-proxy.coffee
# Author: jifeng.zjd <jifeng.zjd@taobao.com>
# 为方便测试,依赖了第三方的websocket包[ws](https://github.com/einaros/ws)

e        = require 'expect.js'
events   = require 'events'
ws       = require 'ws'
proxy    = require '../lib/proxy'
WebSocketServer = require('ws').Server
WebSocket = require('ws')

describe 'websocket testcase', ()->
  port = Math.floor( Math.random() * 9000 + 1000)
  p1 = Math.floor( Math.random() * 9000 + 1000)
  p = proxy()
  p.register({appname: 'websock_app', host: 'localhost', path: p1, prefix: '/'})
  wss = undefined

  before (done)->
    wss = new WebSocketServer({port: p1})
    wss.on 'connection', (ws) ->
      ws.on 'message', (message)->
        # console.log('received: %s', message.toString())
        ws.send 'message: ' + message.toString()
    p.listen port, '0.0.0.0', done

  it 'ws ok', (done)->
    url = 'ws://localhost:' + p1 + '/ws'
    ws = new WebSocket(url)
    ws.on 'open', () ->
      ws.send 'ws something'
    ws.on 'message', (data, flags) ->
      e(data.toString()).to.eql('message: ws something')
      done()

  it 'proxy ws ok', (done)->
    url = 'ws://localhost:' + port + '/ws'
    ws = new WebSocket(url)
    ws.on 'open', () ->
      ws.send 'proxy something'
    ws.on 'message', (data, flags) ->
      e(data.toString()).to.eql('message: proxy something')
      done()