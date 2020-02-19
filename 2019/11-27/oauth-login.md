---
author: Frost Ming
category: 编程
date: 2019-11-27 06:20:59.286005
description: ''
image: https://images.unsplash.com/photo-1425421640640-64c4debea1b4?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1350&q=80
tags:
- Python
- 博客
- Flask
title: Flask 博客接入第三方登录
---

> 在[上一篇文章](https://frostming.com/2019/11-22/comment-system)中我留了一部分内容，就是如何给评论登录接入第三方登录。我不希望来访问我博客的用户有太大的登录成本，否则本想留下些话的人，就会被挡在这个门槛之外。
 
Flask不像Django一样有各种现成的组件可以选用，Flask的各种扩展也不那么「开箱即用」。在我的博客项目中，我选用的是[Authlib](https://authlib.org)，它是国内的一名Python资深开发者[@lepture](https://github.com/lepture)开发的一款全面完善的OAuth认证库。大家可能在别的教程里会看到用的是[flask-oauthlib](https://github.com/lepture/flask-oauthlib)，它们的作者其实是同一人，而且在2019年的今天，我绝对会推荐你用Authlib而不是flask-oauthlib。

> 网上能搜索到的教程，有很多都已经过时，或者不那么「与时俱进」了，截止今天Flask已经到1.1.1版本了，而很多教程还停留在0.10.x时代[^1]。我是个喜欢与时俱进的人，我写的Flask相关文章，以及这个博客项目，保证都是基于最新的推荐，并会尽量保持更新。

[^1]: 比如`Flask-Script`这个扩展，我不推荐任何新的Flask项目使用，因为Flask从0.11.0开始已经内置了命令行的支持。

## 开发思路

首先我们要搞清楚我们需要第三方登录来做什么。很简单，获取用户的邮箱地址（用于通知）、用户头像、用户名称（用于展示）这些基本的信息。登录时，我们到对应的平台上获取令牌，然后通过此令牌去请求用户信息，存到我们的数据库里，以备后面使用。如果大家对OAuth不太了解的，OAuth分为OAuth1协议与OAuth2协议，是一种开放的用户认证协议，它允许任何已注册的外部调用方(Client)，获取平台(Provider)内部的授权访问的资源。OAuth2协议更加简化些，我预备接入的Github和Google都属于这一种协议，认证的主要过程是：
![oauth.png](//static.frostming.com/images/2019-11-oauth.png)

## 接入过程

Github的OAuth2接入是最简单的，很多教程都选择以Github为例，所以我这里选择用Google为例。
第一步，到[Google API Console](https://console.developers.google.com/apis/credentials)申请OAuth2凭据
![google1.png](//static.frostming.com/images/2019-11-google1.png)
选择Web应用，填入你的应用名称，和已获授权的重定向URI，在上图中，当你确认授权访问以后，Google会重定向到这个URI进行后续的动作。访问这个URI时会带上code的信息，一般地，这个URI的视图函数中应该做三件事情：

1. 使用传入的code去Google交换访问令牌
2. 存储访问令牌
3. 使用访问令牌获取用户信息

完成了以后你就可以看到你的**客户端ID**和**客户端密钥**了。

## Authlib的使用

安装过程就不用说了，用`pip`安装即可。先在`models.py`中加入一个新的表：
```python

class OAuth2Token(db.Model):
    id = db.Column(db.Integer(), primary_key=True)
    name = db.Column(db.String(40))
    token_type = db.Column(db.String(40))
    access_token = db.Column(db.String(200))
    refresh_token = db.Column(db.String(200))
    expires_at = db.Column(db.Integer())
    user_id = db.Column(db.Integer(), db.ForeignKey("user.id"))
    user = db.relationship("User", backref=db.backref("tokens", lazy="dynamic"))

    def to_token(self):
        return dict(
            access_token=self.access_token,
            token_type=self.token_type,
            refresh_token=self.refresh_token,
            expires_at=self.expires_at,
        )
```
然后创建`oauth`对象：
```python
from authlib.integrations.flask_client import OAuth

def fetch_token(name):
    token = OAuth2Token.query.filter_by(name=name, user=current_user).first()
    return token.to_token()


def update_token(name, token, refresh_token=None, access_token=None):
    if refresh_token:
        item = OAuth2Token.filter_by(name=name, refresh_token=refresh_token).first()
    elif access_token:
        item = OAuth2Token.filter_by(name=name, access_token=access_token).first()
    else:
        return
    if not item:
        return
    # update old token
    item.access_token = token['access_token']
    item.refresh_token = token.get('refresh_token')
    item.expires_at = token['expires_at']
    db.session.commit()


oauth = OAuth(fetch_token=fetch_token, update_token=update_token)

google = oauth.register(
    name='google',
    access_token_url='https://www.googleapis.com/oauth2/v4/token',
    access_token_params={'grant_type': 'authorization_code'},
    authorize_url='https://accounts.google.com/o/oauth2/v2/auth?access_type=offline',
    authorize_params=None,
    api_base_url='https://www.googleapis.com/',
    client_kwargs={'scope': 'email profile'}
)
```
`fetch_token`和`update_token`两个函数是Authlib需要用来获取和更新令牌用的。然后，在配置文件中加入两个配置：
```python
GOOGLE_CLIENT_ID = os.getenv('GOOGLE_CLIENT_ID')
GOOGLE_CLIENT_SECRET = os.getenv('GOOGLE_CLIENT_SECRET')
```
因为这两个配置是敏感信息，推荐从环境变量读取，不要暴露在代码库中。记得在`create_app`中将`oauth`对象注册到`Flask`中：
```python
oauth.init_app(app)
```
好了，现在我们可以来写视图了：
```python
def google_login():
    origin_url = request.headers['Referer']
    session['oauth_origin'] = origin_url
    redirect_uri = url_for('.google_auth', _external=True)
    if not current_app.debug:
        redirect_uri = redirect_uri.replace('http://', 'https://')
    return google.authorize_redirect(redirect_uri)

def google_auth():
    token = google.authorize_access_token()
    # save token
    resp = google.get('oauth2/v3/userinfo')
    resp.raise_for_status()
    profile = resp.json()
    # save profile
```
注意到我在`login`函数中把`request.headers['Referer']`的值保存到了会话中，这是为了登录成功后跳转会原来的页面，而中途会跳转到外部的网址，所以需要把原地址记下来。跳转google认证地址的URL中需要包含回调的地址，而这个地址必须和之前在Google API Console中配置的地址一致（可以允许是子页面）。现在我们就可以使用第三方登录了。

## 进一步简化

大家可以发现这样使用我们必须知道Google的认证地址、令牌地址和一些额外请求参数，虽然我们可以查阅[Google OAuth文档]获取这些信息，但这多少也是一种负担。所以authlib甚至提供一个库[loginpass](https://github.com/authlib/loginpass)，包含几乎所有主流的OAuth提供方，使用loginpass以后，上面的三段代码可以替换成下面几行：
```python
from flask import Flask
from authlib.integrations.flask_client import OAuth
from loginpass import create_flask_blueprint, Google

app = Flask(__name__)
oauth = OAuth(app)

def handle_authorize(remote, token, user_info):
    if token:
        save_token(remote.name, token)
    if user_info:
        save_user(user_info)
        return user_page
    raise some_error

github_bp = create_flask_blueprint(Google, oauth, handle_authorize)
app.register_blueprint(github_bp, url_prefix='/google')
```

* * *
我的博客即将同步至腾讯云+社区，邀请大家一同入驻：https://cloud.tencent.com/developer/support-plan?invite_code=23bvqemu5etcw