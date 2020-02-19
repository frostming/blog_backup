---
author: null
category: 编程
date: 2017-04-05 19:31:31
description: null
image: //static.frostming.com/images/diary-2134248_1920.jpg
tags:
- Web
- Python
- Flask
title: Flask 实现远程日志实时监控
---

[![](https://badge.juejin.im/entry/58e5a36ea22b9d00588859d3/likes.svg?style=flat)](https://juejin.im/entry/58e5a36ea22b9d00588859d3/detail)

> ## 更新于2019.11.18
> * 去除业务相关逻辑
> * 示例代码仓库在 https://github.com/frostming/flask-webconsole-example

## 前言

在自动化运维系统中，常常需要监控日志，这些日志是不断更新的。本文提供了一种实时日志监控的 Python 实现。主要实现以下功能：

* 抓取远程机器的终端输出到服务器上。
* 将服务器的日志更新实时显示到客户端网页上。

文中示例基于 Python 以及 Flask。

主要依赖：

* [Flask](http://flask.pocoo.org/)
* [Redis](https://redis.io/) 及其 Python [客户端](https://github.com/andymccurdy/redis-py)
* [paramiko](http://www.paramiko.org/)
<!--more-->

## 分析

总体来说要完成实时监控日志的功能需要分为两个方面：

1. 实时读取远程输出
2. 将输出实时显示到页面上

## 获取远程输出

那么下面要解决的问题是如何从远程机器上获取终端输出并添加到日志队列中。在 Python 中，SSH 连接相关的库是 paramiko，于是我自然就想用下面的方法：

```python
client = paramiko.SSHClient()
client.load_system_host_keys()
client.connect(host)
stdin, stdout, stderr = client.exec_command(command)
for line in stdout:
    print(line)
```
这样是挺好的，但是很多时候日志输出时杂糅了标准输出与错误输出的，我希望能有一种方法，检测到有新输出则显示输出，有新错误则显示错误，就像Terminal里面那样。所幸我们可以利用更低一级的channel对象来实现：
```python
def do_run_command(host, username, password, command, key):
    client = paramiko.SSHClient()
    hostname, port = host.split(':')
    client.load_system_host_keys()
    try:
        client.connect(hostname, port, username, password)
        stdin, stdout, stderr = client.exec_command(command)
        channel = stdout.channel
        pending = err_pending = None
        while not channel.closed or channel.recv_ready() or channel.recv_stderr_ready():
            readq, _, _ = select.select([channel], [], [], 1)
            for c in readq:
                if c.recv_ready():
                    chunk = c.recv(len(c.in_buffer))
                    if pending is not None:
                        chunk = pending + chunk
                    lines = chunk.splitlines()
                    if lines and lines[-1] and lines[-1][-1] == chunk[-1]:
                        pending = lines.pop()
                    else:
                        pending = None
                    [push_log(line.decode(), key) for line in lines]
                if c.recv_stderr_ready():
                    chunk = c.recv_stderr(len(c.in_stderr_buffer))
                    if err_pending is not None:
                        chunk = err_pending + chunk
                    lines = chunk.splitlines()
                    if lines and lines[-1] and lines[-1][-1] == chunk[-1]:
                        err_pending = lines.pop()
                    else:
                        err_pending = None
                    [push_log(line.decode(), key) for line in lines]
    finally:
        client.close()
```
这里使用了 select 来控制 IO，另外需要说明的是循环条件：当所有输出都读取完毕时`channel.closed`为`True`，而`exit_status_ready()`是当进程运行结束时就为真了，此时输出不一定都读完了。`pending`和`chunk`是用来整行读取的。

## 日志实时更新

下面我们需要实现一种网页显示，当用户访问时，显示当前日志，若日志有更新，只要网页还打开，无需刷新，日志就是实时更新到网页上。另外，还需要考虑到有多个客户端连接的情况，日志应该是同步更新的。

对于一般的 HTTP 连接，客户端一次请求完毕后立即得到响应，若不重新请求就无法得到新的响应，服务器是被动的。要实现这种客户端的子更新，大致有三种方法：AJAX, SSE 和 Websocket。

* AJAX 就是客户端自动定时发请求，定时间隔事先指定，不是真正的实时。
* SSE 其实是一种长连接，只能实现服务器向客户端主动发送消息。
* Websocket 是服务器与客户端之间的全双工通道，需要后端的软件支持。

权衡以上三者，SSE 是能满足我的要求的代价最小的选择。它的原理是客户端建立一个事件监听器，监听指定 URL 的消息，在服务器端，这个 URL 返回的响应必须是一个流类型。只要将响应体设为一个生成器，并设置头部为`mimetype='text/event-stream'`就行了。在`Flask`上，已经有封装好的扩展`Flask-SSE`，直接安装使用就行了。`Flask-SSE`是通过 Redis 的 Pubsub 实现的消息队列。然而，只有在连接建立以后发送的数据才能收到。只并建立事件监听接受新的日志即可。代码如下：
```
<script>
(function () {
  document.getElementById("post-form").onsubmit = function(e) {
    e.preventDefault();
    var parentNode = document.getElementById('log-container');
    parentNode.innerHTML = "";
    var data = new FormData(document.getElementById('post-form'));
    fetch('/run', {
      method: 'POST',
      body: data
    }).then(resp => resp.json()).then(data => {
      var source = new EventSource('/stream?channel=' + data.uid);
      source.addEventListener('message', function(event) {
        var res = JSON.parse(event.data);
        var pre = document.createElement('pre');
        pre.innerText = res.message;
        parentNode.appendChild(pre);
      });
    });
  }
})();
</script>
```

相应地，添加日志时就要同时发送消息到Pubsub：
```python
def push_log(message, channel):
    sse.publish({'message': message}, 'message', channel=channel)
```

### 几个注意事项

1. 若远程脚本使用python运行时，需要带上`-u`选项，否则`print`的输出不会立即吐出，而是有缓冲。
2. redis 的pubsub 只会收到**连接建立之后**的消息，可能会造成消息丢失。可以在pubsub之外，另外持久化一份消息到redis中，显示时，消息则由「redis中取出的消息」+ 「监听收到的新消息」组成。

> 参考链接：
* [http://flask-sse.readthedocs.io/en/latest/quickstart.html](http://flask-sse.readthedocs.io/en/latest/quickstart.html)
* [http://stackoverflow.com/a/32758464](http://stackoverflow.com/a/32758464)
