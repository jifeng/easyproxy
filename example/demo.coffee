
connect = require 'connect'
http = require 'http'
proxy = require '../index'

work1 = connect()
work1.use connect.bodyParser()
work1.use '/post', (req, res, next) ->
  return res.end JSON.stringify(req.body)

work1.use (req, res, next)->
  res.statusCode = 200
  res.setHeader 'Content-Type', 'text/plain'
  res.end 'work1 is running'
server1 = http.createServer(work1)
p1 = './work1.sock'

work2 = connect()
work2.use (req, res, next)->
  res.statusCode = 200
  res.setHeader 'Content-Type', 'text/plain'
  res.end 'work2 is running'
server2 = http.createServer(work2)
p2 = './work2.sock'

work3 = connect()
work3.use (req, res, next)->
  res.statusCode = 200
  res.setHeader 'Content-Type', 'text/plain'
  res.end 'work2 is running'
server3 = http.createServer(work3)
p3 = './work3.sock'


p = proxy()
p.register({appname: 'work1', host: 'www.work1.com', path: p1, prefix: '/work1'})
p.register({appname: 'work2', host: 'www.work2.com', path: p2, prefix: '/work2'})
p.register({appname: 'work3', host: 'www.work1.com', path: p3, prefix: '/:app/:id/show'})

server1.listen(p1);
server2.listen(p2);
server3.listen(p3);

p.listen(1723);