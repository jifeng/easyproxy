var ws = require('qws');
var http = require('http');
var fs = require('fs');
var path = require('path');

var server = http.createServer(function (req, res) {
  if (req.url.indexOf('.js') > -1) {
    var data = fs.readFileSync(path.join(__dirname, './websocket.js'));
    res.writeHead(200, {'Content-Type': 'application/javascript'});
    res.end(data);
  } else {
    res.writeHead(200, {'Content-Type': 'text/html'});
    res.end('<html><head><script src="./websocket.js"></script></head><body>WebSocket Test</body></html>');
  }
});

ws.createServer(server, function(data, msg) {
  console.log('receive data: ', data);
  msg.write('Get : ' + data);
});

module.exports = server;