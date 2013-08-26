var ws = new WebSocket('ws://localhost:8080/ws');

ws.onopen = function() {
  console.log('open');
  send('test');
};
ws.onclose = function() {
  console.log('close');
};
ws.onmessage = function(e) {
  var message = e.data;
  console.log('message', message);
};
ws.onerror = function(e) {
  console.log(e);
};

function send(msg) {
  // status: ["CONNECTING", "OPEN", "CLOSING", "CLOSED"]
  if (ws.readyState === 1) {
    console.log ('send');
    ws.send(msg);
  }
  else {
    console.log ('unconnected');
  }
}