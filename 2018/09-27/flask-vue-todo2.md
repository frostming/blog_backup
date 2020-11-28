---
category: 编程
date: 2018-09-27 03:59:16.822806
description: 表单与登录
image: //static.frostming.com/images/2018-09-vue-flask.png
tags:
- Python
- Flask
- Vue
template: post
title: Flask前后端分离实践：Todo App(2)
---

> **前序文章**
> * [Flask前后端分离实践：Todo App(1)](https://frostming.com/2018/09-18/flask-vue-todo1)
>   使用Vue.js搭建Todo App
>
> 本文项目地址: https://github.com/frostming/flask-vue-todo

在上一篇文章里我们已经用Flask+Vue搭建了一个可以把数据持久化到服务器的Todo App。那么，为了让多人一起使用这个App，我们需要对数据按用户做隔离，这样就自然需要一个注册/登录界面。在前后端分离的架构里，我们是怎么验证用户，保持会话的呢？

## 用户登录

先复习一下以往用Flask是怎么解决这问题的，没错，通过Flask-Login模块，从request中获取用户名和密码，验证通过后用`login_user`记录到会话中，之后的请求就会带有登录信息了。如果要退出登录，只需要调一下`logout_user`就可以了。

那么使用前后端分离以后，所有对后端的请求都是以Ajax的方式发送，上面的方法依然有效！区别仅仅在于，我们将请求改成JSON格式之后，后端是从`request.get_json()`中获取的。为此，我们专门建立一个名为`auth`的蓝图:

```python
@bp.route('/login', methods=['POST'])
def login():
    user_data = request.get_json()
    form = LoginForm(data=user_data)
    if form.validate():
        user = form.get_user()
        login_user(user, remember=form.remember.data)
        return jsonify({'status': 'success', 'user': user.to_json()})
    return jsonify({'status': 'error', 'message': form.errors}), 403
```

后端只接收POST请求，因为GET都在前端那边，自然也就没有login_view的配置了。前端那边，axios发请求时自动会带上cookie，所以后端这边依然可以通过`flask_login.current_user`拿到当前用户。

## 表单与验证

现在我们需要一个包含表单的登录页面，而我们知道，所有的页面都是前端渲染。所以这里wtform或flask-boostrap就不太能派上用场了。好在表单也比较简单，不是很难写。

```html
<template>
  <form action="/auth/login" method="post">
    <h2>Login</h2>
    <div class="form-group">
      <label for="username">Username</label>
      <input type="text" id="username" name="username" v-model="username" required>
    </div>
    <div class="form-group">
      <label for="password">Password</label>
      <input type="password" id="password" name="password" v-model="password" required>
    </div>
    <div class="form-group">
      <label for="remember">
        <input type="checkbox" id="remember" name="remember" v-model="remember">
        Remember Me
      </label>
    </div>
    <div class="form-footer">
      <button type="submit" name="submit" class="btn">Submit</button>
      <router-link to="/" class="btn">Return Home</router-link>
    </div>
  </form>
</template>
```

有一表单验证的工作，比如必填项，长度限制等，完全不需要后端的，可以在前端完成。我们需要写一个提交的函数，绑定到表单的submit动作上：

```javascript
methods: {
	checkForm (e) {
		e.preventDefault()
		const vm = this
		api.login({
			username: this.username,
			password: this.password,
			remember: this.remember
		}).then(data => {
			vm.$router.push({ path: '/' }, () => {
				vm.success('Logged in successfully!')
			})
		}).catch(e => {
			let errors = e.response.data.message
			for (let key in errors) {
				errors[key].forEach(e => {vm.error(`${key}: ${e}`)})
			}
		})
	}
}
```

但有些验证工作，比如密码校验，还是要麻烦后端的，所以这里我们获取后端返回的错误（储存在`data.message`中），然后依次渲染在页面中（这里我使用了一个Vue的插件[Vue-flask-message](https://www.npmjs.com/package/vue-flash-message)来完成）。

后端验证这一块，由于没有渲染需求了，可以不用wtform这一套，改用[marshmallow](https://github.com/marshmallow-code/marshmallow)，但为了后面的方便，我还是使用了Flask-WTF，把验证放到表单类里。
```python
from flask_wtf import FlaskForm

class LoginForm(FlaskForm):
    username = StringField('Username', validators=[Length(max=64)])
    password = PasswordField('Password', validators=[Length(8, 16)])
    remember = BooleanField('Remember Me')

    def validate_username(self, field):
        if not self.get_user():
            raise ValidationError('Invalid username!')

    def validate_password(self, field):
        if not self.get_user():
            return
        if not self.get_user().check_password(field.data):
            raise ValidationError('Incorrect password!')

    def get_user(self):
        return User.query.filter_by(username=self.username.data).first()
```

完成了登录部分，那么注册界面也大同小异，总结起来，大致思想是：

* 对于无需后端的验证，由前端完成。
* 后端的验证，通过响应内容传回错误。
* 验证错误通过Vue-flash-message显示到页面上。
* login和register的视图函数仅处理POST请求。
