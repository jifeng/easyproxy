require('coffee-script');
var easyproxy = require('../../');
var server = require('./server');

var proxy = easyproxy();

proxy.register({appname: 'work1', host: 'localhost', path: 1723, prefix: '/'});

server.listen(1723, function() {
  console.log('server is working');
});

proxy.listen(8080, '0.0.0.0', function () {
  console.log('proxy is working');
});

