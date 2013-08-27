easyproxy
=========

![logo](https://raw.github.com/jifeng/easyproxy/master/logo.png)

基于http的反向代理

## 特点
* 反向代理功能
* 支持建立在http上的所有协议(HTTP, HTTPS, WebSockets)
* 与[http-proxy](https://github.com/nodejitsu/node-http-proxy)相比，easyproxy跟后端具体服务是走本地socketPath，降低性能损耗
* easyproxy只转发本台服务器上的服务,不跨服务器转发

## 安装
```bash
npm install easyproxy
```

## 使用
为方便介绍，我这里使用的后端http应用采用了connect

###启动应用

```js
var proxy = require('easyproxy');
var http = require('http');
var connet = require('connect');

var work1 = connect()
work1.use(function (req, res, next) {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('work1 is running');
});

var server1 = http.createServer(work1)
var p1 = './work1.sock'

var work2 = connect()
work2.use(function (req, res, next) {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'text/plain');
  res.end('work2 is running');
});
var server2 = http.createServer(work2)
var p2 = './work2.sock'

var p = proxy();
p.register({appname: 'work1', host: 'www.work1.com', path: p1, prefix: '/work1'});
p.register({appname: 'work2', host: 'www.work2.com', path: p2, prefix: '/work2'});

server1.listen(p1);
server2.listen(p2);
p.listen(80);

```

游览器访问www.work1.com/work1 结果

```
work1 is running
```

游览器访问www.work2.com/work2 , 结果

```
work2 is running
```

### 注册应用

```js
p.register({appname: 'work1', host: 'work1.com', path: p1, prefix: '/work1'});
```

### 注销应用

注销某个实例
```js
p.unregister({appname: 'work1', host: 'work1.com', path: p1, prefix: '/work1'});
```

注销某个应用的全部实例
```js
p.unregister('work1');
```

### 清空全部应用
```js
p.clear()
```

### 扩展
#### 请求未注册应用
```js
var p = proxy({noHandler: function (req, res) {
  ......
}});
```
