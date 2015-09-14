
connect = require 'connect'
http = require 'http'
proxy = require '../index'

work1 = connect()
work1.use '/post', (req, res, next) ->
  return res.end JSON.stringify(req.body)

work1.use (req, res, next)->
  ip = req.headers['x-forwarded-for']
  port = req.headers['x-forwarded-for-port']
  res.statusCode = 200
  res.setHeader 'Content-Type', 'text/plain'
  res.end 'work1 is running'
server1 = http.createServer(work1)
port1 = 8080


p = proxy()
p.register({appname: 'work1', host: 'www.work1.com', remote: '127.0.0.1:8080', prefix: '/work1'})

server1.listen(port1);

p.listen(1723);