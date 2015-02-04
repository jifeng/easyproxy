e = require 'expect.js'
request = require 'supertest'
connect = require 'connect'
http = require 'http'
req = require 'request'
proxy = require '../lib/proxy'
os = require 'os'
fs = require 'fs'
ep = require 'event-pipe'

getInterIp = ()->
  rows = os.networkInterfaces().en0
  for row in rows
    return row.address if row.family is 'IPv4'
  return

work1 = connect()

work1.use '/work1/redirect', (req, res, next)->
  res.statusCode = 302;
  res.setHeader('Location', 'http://www.taobao.com');
  res.end();

work1.use '/work1/post', connect.bodyParser()
work1.use '/work1/post', (req, res, next) ->
  res.end JSON.stringify(req.body)
work1.use (req, res, next)->
  res.statusCode = 200
  res.setHeader 'Content-Type', 'text/plain'
  res.setHeader 'X-header', 'value'
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
  e(req.headers).to.have.key('x-forwarded-for')
  e(req.headers).to.have.key('x-forwarded-for-port')
  res.statusCode = 200
  res.setHeader 'Content-Type', 'text/plain'
  res.end 'work3 is running'
server3 = http.createServer(work3)
p3 = './work3.sock'

p = proxy()
p.register({appname: 'work1', host: 'www.work1.com', path: p1, prefix: '/work1'})
p.register({appname: 'work2', host: 'www.work2.com', path: p2, prefix: '/work2'})
p.register({appname: 'work3', host: 'www.work2.com', path: p2, prefix: '/:app/show'})

port = Math.floor(Math.random()* 9000 + 1000)
port2 = Math.floor(Math.random()* 9000 + 1000)
reloadPort = Math.floor(Math.random()* 9000 + 1000)
reloadProxy = proxy()

pserver = proxy
  debug: true

describe 'proxy', () ->
  before (done)->
    fs.unlinkSync p1 if fs.existsSync p1
    fs.unlinkSync p2 if fs.existsSync p2
    fs.unlinkSync p3 if fs.existsSync p3
    item = ep()
    item.add ()->
      server1.listen p1, @
    item.add ()->  
      server2.listen p2, @
    item.add ()->
      server3.listen p3, @
    item.add ()->
      p.listen port, '127.0.0.1', @
    item.add ()->  
      pserver.listen port2, '127.0.0.1', @
    item.add ()->
      reloadProxy.listen reloadPort, '0.0.0.0', @
    item.add ()->
      done()
    item.run()

  after (done)->
    server1.close()
    server2.close()
    server3.close()
    p.clear()
    fs.unlinkSync p1 if fs.existsSync p1
    fs.unlinkSync p2 if fs.existsSync p2
    fs.unlinkSync p3 if fs.existsSync p3
    pserver.clear()
    pserver.close()
    reloadProxy.close()
    p.close(done)

  it 'mock work1 should ok', (done) ->
    request(work1)
    .get('/')
    .expect('work1 is running')
    .end((err, res)->
      e(err).to.equal(null)
      done()
    )

  it 'mock work1 redirect should ok', (done) ->
    request(work1)
    .get('/work1/redirect')
    .expect(302)
    .expect('Location', 'http://www.taobao.com')
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
    req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.headers.server).to.eql 'Easyproxy'
      e(data.headers['HC-Socket']).to.eql undefined
      e(data.headers['x-header']).to.eql 'value'
      e(data.body).to.eql 'work1 is running'
      done();

  it 'get stg.www.work1.com should not ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'stg.www.work1.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.statusCode).to.equal 404
      done();

  it 'get www.work1.com redirect should ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/work1/redirect', headers: {host: 'www.work1.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.req._header).to.contain('host: www.taobao.com')
      done();

  it 'post www.work1.com/work1/post should ok', (done) ->
    options = {
      url: 'http://127.0.0.1:' + port + '/work1/post', 
      headers: {host: 'www.work1.com'},
      form: {a: '1', b: 'b'}
    }
    req.get options, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql '{"a":"1","b":"b"}'
      done();

  it 'get www.work1.com/work2 should not ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/work2', headers: {host: 'www.work1.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.statusCode).to.equal 404
      done();

  it 'get www.work2.com should ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/work2', headers: {host: 'www.work2.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work2 is running'
      done();

  it 'reload success', (done)->
    reloadProxy.reload p.apps
    req.get {url: 'http://127.0.0.1:' + reloadPort + '/work2', headers: {host: 'www.work2.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work2 is running'
      done()

  it 'get www.work2.com :id/show should ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/cdo/show', headers: {host: 'www.work2.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.body).to.eql 'work2 is running'
      done();

  it 'get www.work2.com :id/xxxx/show should not ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/cdo/xxxx/show', headers: {host: 'www.work2.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.statusCode).to.equal 404
      done();


  it 'get www.work2.com/work1 should not ok', (done) ->
    req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work2.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.statusCode).to.equal 404
      done();

  it 'get www.work1.com should return 404', (done) ->
    req.get {url: 'http://127.0.0.1:' + port, headers: {host: 'www.xxxxx.com'}}, (err, data) ->
      e(err).to.equal null
      e(data.statusCode).to.equal 404
      done();

  describe 'debug', ()->
    beforeEach ()->
      pserver.register({appname: 'work3', host: 'www.work3.com', path: p3, prefix: '/work3'})

    afterEach ()->
      pserver.unregister({appname: 'work3', host: 'www.work3.com', path: p3, prefix: '/work3'})

    it 'HC-Socket', (done) ->
      req.get {url: 'http://127.0.0.1:' + port2 + '/work3', headers: {host: 'www.work3.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.body).to.eql 'work3 is running'
        e(data.headers.server).to.eql 'Easyproxy'
        e(data.headers['hc-socket']).to.eql p3
        done();

  describe 'register unregister', ()->
    beforeEach ()->
      p.register({appname: 'work3', host: 'www.work3.com', path: p3, prefix: '/work3'})

    afterEach ()->
      p.unregister({appname: 'work3', host: 'www.work3.com', path: p3, prefix: '/work3'})

    it 'register', (done) ->
      req.get {url: 'http://127.0.0.1:' + port + '/work3', headers: {host: 'www.work3.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.body).to.eql 'work3 is running'
        done();
 
    it 'register same host and prefix but not path', (done)->
      p.register({appname: 'work3', host: 'www.work1.com', path: p3, prefix: '/work1'})
      req.get {url: 'http://127.0.0.1:' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.body).to.eql 'work3 is running'
        p.unregister({appname: 'work3', host: 'www.work1.com', path: p3, prefix: '/work1'})
        done();

    it 'unregister', (done)->
      p.unregister({appname: 'work3', host: 'www.work3.com', path: p3, prefix: '/work3'})
      req.get {url: 'http://127.0.0.1:' + port + '/work3', headers: {host: 'www.work3.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.statusCode).to.equal 404
        done();

    it 'unregister appname', (done)->
      p.unregister('work3')
      req.get {url: 'http://127.0.0.1:' + port + '/work3', headers: {host: 'www.work3.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.statusCode).to.equal 404
        done();

  describe 'register app registered before', () ->      
    
    it '/ and /work5', () ->
      p.register({appname: 'work4', host: 'work4.com', path: p3, prefix: '/'})
      apps = p.apps
      e(apps.length > 0).to.equal true
      flag = 0
      for app in apps
        if app.host is 'work4.com' and app.prefix is '/' and app.status is 'on'
          flag = 1
      e(flag).to.equal 1
      p.register({appname: 'work5', host: 'work4.com', path: p3, prefix: '/work5'})
      flag = 0
      for app in apps
        if app.host is 'work4.com' and app.prefix is '/work5' and app.status is 'on'
          flag = 1
      e(flag).to.equal 0

    it '/work6/ and /work6/s', () ->
      p.register({appname: 'work6', host: 'work6.com', path: p3, prefix: '/work6'})
      apps = p.apps
      e(apps.length > 0).to.equal true
      flag = 0
      for app in apps
        if app.host is 'work6.com' and app.prefix is '/work6/' and app.status is 'on'
          flag = 1
      e(flag).to.equal 1
      p.register({appname: 'work6', host: 'work6.com', path: p3, prefix: '/work6/s'})
      flag = 0
      for app in apps
        if app.host is 'work6.com' and app.prefix is '/work6/s' and app.status is 'on'
          flag = 1
      e(flag).to.equal 0

  describe 'noHandler exist', ()->
    _noHandler = p.options.noHandler
    before ()->
      p.options.noHandler = (req, res) ->
        res.statusCode = 404
        res.end('noHandler exist')    

    after ()->
      p.options.noHandler = _noHandler

    it 'get www.work1.com/work2 should not ok', (done) ->
      req.get {url: 'http://127.0.0.1:' + port + '/work2', headers: {host: 'www.work1.com'}}, (err, data) ->
        e(err).to.equal null
        e(data.statusCode).to.equal 404
        e(data.body).to.eql 'noHandler exist'
        done();

    
  it 'ip is inet not 127.0.0.1 should err', (done)->
    ip = getInterIp()
    inetp = proxy()
    inetp.register({appname: 'work1', host: 'www.work1.com', path: p1, prefix: '/work1'})
    inetp.listen port, ip, ()->
      req.get {url: 'http://127.0.0.1' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data) ->
        e(err).not.to.eql null
        req.get {url: 'http://' + ip + ':' + port + '/work1', headers: {host: 'www.work1.com'}}, (err, data, body) ->
          e(err).to.eql(null)
          e(body).to.eql 'work1 is running'
          done();


  describe 'router handle casese', ()->
    routers = [ { 
      match: (req, res)->
        return '/status.taobao' is req.url
      handle: (req, res)->
        res.statusCode = 200
        res.end('success')
    }, { 
      match: (req, res)->
        return req.headers.host.indexOf('www.monitor.com') >= 0
      handle: (req, res)->
        res.statusCode = 200
        res.end(JSON.stringify(req.apps))
    } ]
    randPort = Math.floor(Math.random()* 9000 + 1000)
    handleProxy = proxy({routers: routers})
    
    before (done)->
      handleProxy.listen randPort, '0.0.0.0', done

    after (done)->
      handleProxy.close done

    it 'mathc ok /status.taobao', (done)->
      req.get {url: 'http://127.0.0.1:' + randPort + '/status.taobao'}, (err, data) ->
        e(err).to.eql(null)
        e(data.body).to.eql('success')
        done()

    it 'math ok host', (done)->
      req.get {url: 'http://127.0.0.1:' + randPort,  headers: {host: 'www.monitor.com'}}, (err, data) ->
        e(err).to.eql(null)
        e(data.body).to.eql('[]')
        done()

  describe 'fix bug about when map not init when request comming', ()->
    initProxyPort = Math.floor( Math.random() * 9000 + 1000)
    initProxy = proxy()
    before (done)->
      initProxy.listen initProxyPort, '0.0.0.0', done
      
    it 'fail and success', (done)->    
      ep(->
        req {url: 'http://127.0.0.1:' + initProxyPort + '/work1', headers: {host: 'www.work1.com'}}, @
      , (err, _$, body)->
        e(body).to.contain 'app is not registered'
        initProxy.register({appname: 'work1', host: 'www.work1.com', path: p1, prefix: '/work1'})
        req {url: 'http://127.0.0.1:' + initProxyPort + '/work1', headers: {host: 'www.work1.com'}}, @
      , (err, _$, body)->
        e(body).to.eql 'work1 is running'
        done()
      ).run()


