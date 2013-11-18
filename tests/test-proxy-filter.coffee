e = require 'expect.js'
connect = require 'connect'
http = require 'http'
req = require 'request'
proxy = require '../lib/proxy'
fs = require 'fs'

createServer = (content)->
  work = connect()
  work.use (req, res, next)->
    res.statusCode = 200
    res.setHeader 'Content-Type', 'text/plain'
    res.end content
  http.createServer(work)

p1 = 'work-1' + Math.floor(Math.random() * 9000 + 1000) + '.sock'
p2 = 'work-2' + Math.floor(Math.random() * 9000 + 1000) + '.sock'
port = Math.floor(Math.random() * 9000 + 1000)

server1 = createServer('work ' + p1 + ' is working');
server2 = createServer('work ' + p2 + ' is working');

p = proxy()
p.register({appname: 'work-filter', host: 'www.work1.com', path: p1, prefix: '/work1'})
p.register({appname: 'work-filter', host: 'www.work1.com', path: p2, prefix: '/work1'})

 
describe 'proxy filter', ()->
  before (done)->
    fs.unlinkSync p1 if fs.existsSync p1
    fs.unlinkSync p2 if fs.existsSync p2
    server1.listen p1, ()->
      server2.listen p2, () ->
        p.listen port, '127.0.0.1', done

  after (done)->
    fs.unlinkSync p1 if fs.existsSync p1
    fs.unlinkSync p2 if fs.existsSync p2
    done();

  it 'filter success', (done)->
    filter = (options)->
      targets = options.targets
      e(targets.length).to.eql(2)
      return p1
    p.clearFilters()
    req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work ' + p2 + ' is working'
      p.bindFilter filter
      req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.body).to.eql 'work ' + p1 + ' is working'
        done();
  

  it 'filter success not founded', (done)->
    filter = (options)->
      targets = options.targets
      e(targets.length).to.eql(2)
      return
    p.clearFilters()
    req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work ' + p2 + ' is working'
      p.bindFilter filter
      req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.body).to.eql 'work ' + p2 + ' is working'
        done();
 

   it 'filter success not error happen', (done)->
    filter = (options)->
      targets = options.targets
      a = bxxxx
    p.clearFilters()
    req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work ' + p2 + ' is working'
      p.bindFilter filter
      req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.body).to.eql 'work ' + p2 + ' is working'
        done(); 

