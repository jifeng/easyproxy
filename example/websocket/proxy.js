require('coffee-script');
var easyproxy = require('../../');
var server = require('./server');

var proxy = easyproxy();

path = './websocket.sock';
proxy.register({appname: 'work1', host: 'localhost', path: path, prefix: '/'});

server.listen(path, function() {
  console.log('server is working');
});

proxy.listen(8080, '0.0.0.0', function () {
  console.log('proxy is working');
});

