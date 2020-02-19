---
author: null
category: 编程
date: 2016-06-03 18:00:00
description: null
image: //static.frostming.com/images/requests-sidebar.png
tags:
- Python
- Requests
- 源码阅读
title: Requests源码阅读v0.8.0
---

> 工作两年了，一直用python写一些API之类的东西，自动化框架也有涉及，却一直感觉对个人技能提升缓慢。决定开这个坑，是之前看到[@wangshunping](https://github.com/wangshunping/read_requests)的**read requests**，生动有趣，可惜0.8.0之后没有更新了。待我稍稍有了一点看源码的动力，就想接着下去写。真是漫漫长路啊，4409个commit，1000多个PR，更何况还有珠玉在前，实在没有把握能把这块硬骨头给啃下来，写一点是一点吧。作为python的小学生，一些错误在所难免，希望大家指出，互相讨论。
> 下面就开始吧！

<!--more-->
## 目标
```
0.8.0 (2011-11-13)
++++++++++++++++++

* Keep-alive support!
* Complete removal of Urllib2
* Complete removal of Poster
* Complete removal of CookieJars
* New ConnectionError raising
* Safe_mode for error catching
* prefetch parameter for request methods
* OPTION method
* Async pool size throttling
* File uploads send real names
```

## 源码阅读
### v0.7.1

```
0.7.1 (2011-10-23)
++++++++++++++++++

* Move away from urllib2 authentication handling.
* Fully Remove AuthManager, AuthObject, &c.
* New tuple-based auth system with handler callbacks.
```
* 移除`urllib2`的authentication处理
* 完全移除`AuthManager`, `AuthObject`和。。。&c？
* 新的元组形式的`auth`机制和处理器回调函数。

#### 1. 移除`urllib2`的authentication处理
添加一个`auth.py`文件，加入了自己实现的auth处理器，包含`http_basic`和`http_digest`，分别对应Headers中`Autohorization`以`Basic`和`Digest`开头的情形。
#### 2. 完全删除`AuthManager`, `AuthObject`和。。。&c？
由于接口改用了session，于是就没有必要使用`AuthManager`储存认证信息。使用自己实现的处理器，完全删除`models.py`中相关的代码。
#### 3. 新的元组形式的`auth`机制和处理器回调函数。
现在：
```python
self.auth = auth_dispatch(auth)

if self.auth:
    auth_func, auth_args = self.auth
    r = auth_func(self, *auth_args)
    self.__dict__.update(r.__dict__)
```
```python
def dispatch(t):
    """Given an auth tuple, return an expanded version."""

    if not t:
        return t
    else:
        t = list(t)

    # Make sure they're passing in something.
    assert len(t) >= 2

    # If only two items are passed in, assume HTTPBasic.
    if (len(t) == 2):
        t.insert(0, 'basic')

    # Allow built-in string referenced auths.
    if isinstance(t[0], basestring):
        if t[0] in ('basic', 'forced_basic'):
            t[0] = http_basic
        elif t[0] in ('digest',):
            t[0] = http_digest

    # Return a custom callable.
    return (t[0], tuple(t[1:]))
```
通过`dispatch`函数，若传入二元元组，则默认前面加上`'basic'`，使用`http_basic`处理，否则需要指定处理类型。支持自定义处理器：
```python
def pizza_auth(r, username):
    """Attaches HTTP Pizza Authentication to the given Request object.
    """
    r.headers['X-Pizza'] = username

    return r

Then, we can make a request using our Pizza Auth::

>>> requests.get('http://pizzabin.org/admin', auth=(pizza_auth, 'kenneth'))
<Response [200]>
```
### v0.7.2
```
0.7.2 (2011-10-23)
++++++++++++++++++

* PATCH Fix.
```
修正BUG（略）

### v0.7.3
```
0.7.3 (2011-10-23)
++++++++++++++++++

* Digest Auth fix.
```
修正Digest Auth的BUG
主要是删除了一些debug的print语句，估计当时作者脑子也不清醒了，我还注意到他改了一个文件头的"~"的长度，是有够无聊的！0.7.1到0.7.3都在一个多小时内完成，小伙子动力很足啊！

### v0.7.4
```
0.7.4 (2011-10-26)
++++++++++++++++++

* Sesion Hooks fix.
```
主要是一些代码的美化和小BUG，给`session`加了一个`keep_alive`参数，暂时还没用上，应该是为以后做准备。
### v0.7.5
```
0.7.5 (2001-11-04)
++++++++++++++++++

* Response.content = None if there was an invalid repsonse.
* Redirection auth handling.
```
咦？日期穿越了10年？哈哈，什么时候会改呢？
* 如果是无效响应则`content = None`
* 重定向认证处理

#### 1. 无效响应`content = None`
加入一个Error Handling:
```python
try:
    self._content = self.raw.read()
except AttributeError:
    return None
```
#### 2. 重定向认证处理
一个BUG，原来是用dispatch后的auth构造新的Request会导致错误，现在使用`self._auth`保存原始auth并传入新的Request对象。

### v0.7.6
```
0.7.6 (2011-11-07)
++++++++++++++++++

* Digest authentication bugfix (attach query data to path)
```
* Digest 认证的BUG 修复（在路径后附上query）

原来：
```python
path = urlparse(r.request.url).path
```
现在：
```python
p_parsed = urlparse(r.request.url)
path = p_parsed.path + p_parsed.query
```
我注意到日期问题已经修复了：
> Updated your 2001, to 2011... unless you went back in time ;)

这个幽默。
### v0.8.0
```
0.8.0 (2011-11-13)
++++++++++++++++++

* Keep-alive support!
* Complete removal of Urllib2
* Complete removal of Poster
* Complete removal of CookieJars
* New ConnectionError raising
* Safe_mode for error catching
* prefetch parameter for request methods
* OPTION method
* Async pool size throttling
* File uploads send real names
```
* 支持`keep_alive`参数（填坑来了）
* 完全抛弃`urllib2`
* 完全抛弃`Poster`
* 完全抛弃`CookieJars`
* 新的`ConnectionError`抛出
* 安全的处理异常机制。
* 为请求方法加入`prefetch`参数
* 新的`OPTION`方法
* 节省Async池的大小
* 上传文件发送真实文件名

#### 1. 支持`keep_alive`参数
作者在v0.8.0全面转向`urllib3`，这是个第三方的轮子，它相对于`urllib2`最大的改进是可以重用 HTTP 连接，不用每个 request 都新建一个连接了。这样大大加快了大量 request 时的响应速度。
```python
self.poolmanager = PoolManager(
    num_pools=self.config.get('pool_connections'),
    maxsize=self.config.get('pool_maxsize')
)
```
```python
proxy = self.proxies.get(_p.scheme)

if proxy:
    conn = poolmanager.proxy_from_url(url)
else:
    # Check to see if keep_alive is allowed.
    if self.config.get('keep_alive'):
        conn = self._poolmanager.connection_from_url(url)
    else:
        conn = connectionpool.connection_from_url(url)
```
`keep_alive`是默认打开的，在`urllib3`中维护了一个连接池，当对某个url进行请求时，会从连接池中取出该连接，然后发送请求时直接调用此连接的子方法。

#### 2. 完全抛弃`urllib2`
删除了`models.py`中用来发送请求的`build_opener`函数，使用`urllib3`的`conn.urlopen`方法。

#### 3.完全抛弃`Poster`
同上，用一个轮子换了另一个轮子。。

#### 4. 完全抛弃`CookieJars`
上测试
```python
def test_session_persistent_cookies(self):

    s = requests.session()

    # Internally dispatched cookies are sent.
    _c = {'kenneth': 'reitz', 'bessie': 'monke'}
    r = s.get(httpbin('cookies'), cookies=_c)
    r = s.get(httpbin('cookies'))

    # Those cookies persist transparently.
    c = json.loads(r.content).get('cookies')
    assert c == _c

    # Double check.
    r = s.get(httpbin('cookies'), cookies={})
    c = json.loads(r.content).get('cookies')
    assert c == _c

    # Remove a cookie by setting it's value to None.
    r = s.get(httpbin('cookies'), cookies={'bessie': None})
    c = json.loads(r.content).get('cookies')
    del _c['bessie']
    assert c == _c

    # Test session-level cookies.
    s = requests.session(cookies=_c)
    r = s.get(httpbin('cookies'))
    c = json.loads(r.content).get('cookies')
    assert c == _c

    # Have the server set a cookie.
    r = s.get(httpbin('cookies', 'set', 'k', 'v'), allow_redirects=True)
    c = json.loads(r.content).get('cookies')

    assert 'k' in c

    # And server-set cookie persistience.
    r = s.get(httpbin('cookies'))
    c = json.loads(r.content).get('cookies')

    assert 'k' in c
```
处理响应的cookie:
```python
if 'set-cookie' in response.headers:
    cookie_header = response.headers['set-cookie']

    c = SimpleCookie()
    c.load(cookie_header)

    for k,v in c.items():
        cookies.update({k: v.value})

# Save cookies in Response.
response.cookies = cookies
cookies = self.cookies
self.cookies.update(r.cookies)
```
发送请求时：
```python
if self.cookies:

    # Skip if 'cookie' header is explicitly set.
    if 'cookie' not in self.headers:

        # Simple cookie with our dict.
        c = SimpleCookie()
        for (k, v) in self.cookies.items():
            c[k] = v

        # Turn it into a header.
        cookie_header = c.output(header='').strip()

        # Attach Cookie header to request.
        self.headers['Cookie'] = cookie_header
```
使用了标准库里的`SimpleCookie`处理和生成cookie，而读取cookie全部都是字典类型。其实这些都是为了新的`urllib3`接口而服务的，从原来的各种Handler改成`conn.urlopen`以后原来的东西都相应的变化。

#### 5. 新的`ConnectionError`

#### 6. 安全模式
直接看代码吧：
```python
except MaxRetryError, e:
    if not self.config.get('safe_mode', False):
        raise ConnectionError(e)
    else:
        r = None

except (_SSLError, _HTTPError), e:
    if not self.config.get('safe_mode', False):
        raise Timeout('Request timed out.')
```
所谓安全模式就是不抛出异常。

#### 7. 新的`prefetch`参数
也是`urllib3`支持的参数，当为`True`时，在发送请求时就读取响应内容，否则跟原来一样调用`content`方法时读取。至于这个有什么用我还不是太懂，因为我发现当`prefetch=True`时读取`content`会出错并且无法获取响应内容，疑似BUG，先放在这里。

#### 8. `OPTION`请求方法
Option 是一种 HTTP 的请求类型，返回当前 url 支持的全部方法。

#### 9. 节省 async 池的大小
原来：
```python
jobs = [gevent.spawn(send, r) for r in requests]
gevent.joinall(jobs)
```
现在：
```python
if size:
    pool = Pool(size)
    pool.map(send, requests)
    pool.join()
else:
    jobs = [gevent.spawn(send, r) for r in requests]
    gevent.joinall(jobs)
```
大概就是传入一个`size`参数，所有的异步请求都在这个有限大小的池里处理，嗯，又是池，真是一个好用的东西。

#### 10. 上传文件时包含真实文件名
看代码：
```python
def guess_filename(obj):
    """Tries to guess the filename of the given object."""
    name = getattr(obj, 'name', None)
    if name and name[0] != '<' and name[-1] != '>':
        return name
```
嗯，怎么得到真实文件名？靠猜啊，没有就拉倒。

## 后记

呼，终于整完了，v0.8.0 包含一个大的重构，我这个累的啊。第一次写这种东西，感觉不是很满意，代码太多了自己的试验不太够，总的也就能理解 80% 左右吧。不管怎样，谢谢大家的阅读，欢迎交流。
