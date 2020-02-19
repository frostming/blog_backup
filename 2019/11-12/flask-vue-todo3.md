---
author: Frost Ming
category: 编程
date: 2019-11-12 08:12:34.660077
description: CSRF防护与后端鉴权
image: //static.frostming.com/images/2018-09-vue-flask.png
tags:
- Python
- Flask
- Vue
title: Flask前后端分离实践：Todo App(3)
---

> **前序文章**
> 
> * [Flask前后端分离实践：Todo App(1)](https://frostming.com/2018/09-18/flask-vue-todo1)
> * [Flask前后端分离实践：Todo App(2)](https://frostming.com/2018/09-27/flask-vue-todo2)
> 
> 本文项目地址: https://github.com/frostming/flask-vue-todo

***作者按***: 几天前我收到一封邮件，有读者说看了我的前后端分离实践的文章获益很多。然而我却丧尽天良的断更了？不行不行，我不是这样的人，所以一年后，我再补上这个系列最后一篇文章吧。

## CSRF防护

如果你们是看了Miguel的[狗书][1]，或是李辉大大的[狼书][2]，一定知道我们在提交表单时，常常会附带上一个隐藏的csrf值，用来防止CSRF攻击。关于CSRF是什么这里就不过多介绍了，大家可以参阅[维基百科][3]。那么我们来到前后端分离的世界，CSRF应该如何做呢？因为是前后端分离，所以服务端产生的CSRF值并不能实时更新到页面上，页面的更新全都要依赖客户端去主动请求。那我是不是要每次渲染表单的时候，就去服务器取一次CSRF token呢？这未免太麻烦，我们完全可以减少请求的次数，请求一次，然后在客户端（浏览器）上存起来，要用的时候带上即可。

[1]: https://www.amazon.cn/dp/B07KW12YLN/ref=sr_1_2?__mk_zh_CN=亚马逊网站&keywords=flask+web开发&qid=1573545635&sr=8-2
[2]: https://www.amazon.cn/dp/B07GST8Z8M/ref=sr_1_1?__mk_zh_CN=亚马逊网站&keywords=flask+web开发&qid=1573545635&sr=8-1
[3]: https://zh.wikipedia.org/wiki/跨站请求伪造

在Flask中引入CSRF保护主要是用Flask-WTF这个扩展，但既然我们不用WTF去渲染表单了，那么表单的CSRF保护也用不上了，所幸，这个扩展还提供了一个全局CSRF保护方法，就是所有view都可以通过一个模板变量去获取CSRF token的值，并不仅限于表单。开启方法也很简单：

```python
from flask_wtf.csrf import CSRFProtect

csrf = CSRFProtect(app)
# 或者使用工厂函数模式：
csrf = CSRFProtect()
def create_app():
    app = Flask(__name__)
    ...
    csrf.init_app(app)
    return app
```
这样在模板中，可以通过`{{ csrf_token() }}`获得CSRF token的值。推荐放在返回的前端页面`index.html`的meta标签中，以供ajax方法获取
```html
...
<header>
  <meta name="csrf-token" content="{{ csrf_token() }}">
...
```
然后在ajax请求中，取出这个值然后带上即可，这里展示一下如何用`axios`实现：
```javascript
const api = axios.create({
  headers: {
    'Content-Type': 'application/json',
    'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]').getAttribute('content')}
})
```
这也是我这个todo项目采用的方法，但这种方法有一个很大的限制：前端页面必须至少由Flask应用渲染一次，这只能叫做半个前后端分离。实际开发中，前端和后端可能完全是分离部署，通过nginx等其他web服务器返回的。这样一来，`{{ csrf_token() }}`就完全没机会透给前端。不要紧，我们还可以用Cookies嘛。当然，这需要自己定制一下`Flask-WTF`这个扩展，可以查看这个[代码示例](https://gist.github.com/frostming/dbb514c8ae1e9363039e9df537988812)。在Django中，默认采用的就是这种方式。

## 后端鉴权

好了，我们又用到了Cookie，如果有人对上一篇还有印象的话（并没有），用户的登录态也是放在cookie里面的，这种方案对于一般的普通应用就足够了，我一直提倡如果某种方法够用，就不用急着使用更高级的方法。但当某些客户端不支持cookie的时候（比如手机app），我们就需要新的方法了。

当然，这个解决方案现在也很成熟了，就是[JWT(JSON Web Token)](https://en.wikipedia.org/wiki/JSON_Web_Token)。大概流程是，第一次打开页面时，请求后端，如果没登录，则返回401让前端跳转登录，如果是登录状态，则返还一个Token，这个token自带某些用户信息，和过期时间。前端收到这个token则自己保存起来，保存方式可以是cookie，也可以是localstorage，然后后续的请求均带上这个token，前后端之间仅仅依靠这个token鉴定身份，无需来回传送cookie或会话信息。
![jwt.jpg](//static.frostming.com/images/2019-11-jwt.jpg)

JWT的好处是服务端无需保存这个token值，token本身就带有是否有效的信息，以及登录态的关键信息（比如user id），而token是通过服务端密钥加密的，所以难以被破解。Flask内置了一个``itsdangerous``的库来生成这种token，先总结一下，Flask要做的事有：

1. 每次请求都校验这个token值，若不通过则返回401
2. login端点生成token值
3. logout端点清除token值

```python
@app.before_request
def validate_request():
    token = request.headers.get('X-Token')
    if not token:
        abort(401)
    user = User.verify_token(token)
    if not user:
        abort(401)
    g.current_user = user

@api.route('/user/login', methods=['POST'])
def login():
    data = request.get_json()
    if not verify_auth(data.get('username'), data.get('password')):
        return jsonify(
            {'code': 60204, 'message': 'Account and password are incorrect.'}
        )
    return jsonify({'code': 20000, 'data': {'token': g.user.generate_token().decode()}})
```
```python
from itsdangerous import (
    TimedJSONWebSignatureSerializer as Serializer,
    BadSignature,
    SignatureExpired,
)

class User(db.Model):
    ...
    @classmethod
    def verify_auth_token(cls, token):
        s = Serializer(current_app.config["SECRET_KEY"])
        try:
            data = s.loads(token)
        except (BadSignature, SignatureExpired):
            return None
        user = cls.query.get(data["id"])
        return user

    def generate_token(self, expiration=24 * 60 * 60):
        s = Serializer(current_app.config["SECRET_KEY"], expires_in=expiration)
        return s.dumps({"id": self.id})
```

而前端请求ajax时，只需要把这个事先保存好的token值取出来加到请求头部`X-Token`就可以了。


## 总结

好了，我想这三篇文章已经覆盖了前后端分离与传统MVC架构的主要区别和开发技巧，当然还有更多的点我没法覆盖到，欢迎到评论区或邮件骚扰我。