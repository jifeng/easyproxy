e = require 'expect.js'
request = require 'supertest'
connect = require 'connect'
http = require 'http'
req = require 'request'
proxy = require '../'


work1 = connect()
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
  res.end 'work3 is running'
server3 = http.createServer(work3)
p3 = './work3.sock'

p = proxy()
p.register({appname: 'work1', host: 'work1.com', path: p1, prefix: '/work1'})
p.register({appname: 'work2', host: 'work2.com', path: p2, prefix: '/work2'})
port = Math.floor(Math.random()* 9000 + 1000)

describe 'proxy', () ->
  before (done)->
    server1.listen p1, ()->
      server2.listen p2, () ->
        server3.listen p3, () ->
          p.listen port, done


  after ()->
    server1.close()
    server2.close()
    server3.close()
    p.close()

  it 'mock work1 should ok', (done) ->
    request(work1)
    .get('/')
    .expect('work1 is running')
    .end((err, res)->
      e(err).to.equal(null)
      done()
    )

  it 'mock work2 should ok', (done) ->
    request(work2)
    .get('/')
    .expect('work2 is running')
    .end((err, res)->
      e(err).to.equal(null)
      done()
    )

  it 'get www.work1.com should ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port, headers: {host: 'www.work1.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work1 is running'
      done();

  it 'get www.work2.com should ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port, headers: {host: 'www.work2.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work2 is running'
      done();

  it 'get www.work1.com should return 404', (done) ->
    req.get {url: 'http://127.0.0.1:' + port, headers: {host: 'www.xxxxx.com'}}, (err, data) ->
      e(err).not.to.equal null
      done();

  it 'get www.localhost/work1 should ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/work1'}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work1 is running'
      done();

  it 'get www.localhost/work2 should ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/work2'}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work2 is running'
      done();

  describe 'register unregister', ()->
    before ()->
      p.register({appname: 'work3', host: 'work3.com', path: p3, prefix: '/work3'})

    after ()->
      p.unregister({appname: 'work3', host: 'work3.com', path: p3, prefix: '/work3'})

    it 'register', (done) ->
      req.get {url: 'http://127.0.0.1:' + port, headers: {host: 'www.work3.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.body).to.eql 'work3 is running'
        done();

    it 'unregister', ()->
      p.unregister({appname: 'work3', host: 'work3.com', path: p3, prefix: '/work3'})
      req.get {url: 'http://127.0.0.1:' + port, headers: {host: 'www.work3.com'}}, (err, data) ->
        e(err).not.to.equal null
        done();




