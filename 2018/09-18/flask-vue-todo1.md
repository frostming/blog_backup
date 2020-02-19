---
author: Frost Ming
category: 编程
date: 2018-09-18 07:49:20.101906
description: 使用Vue.js搭建Todo App
image: //static.frostming.com/images/2018-09-vue-flask.png
tags:
- Python
- Flask
- Vue
title: Flask前后端分离实践：Todo App(1)
---

> **前言**：有句老话，叫做「现在都8102年了，你怎么还XXX？」。随着前端工具的越来越完善和好用，现在前端能做的东西，实在太多了。而现在主流的Flask教程，都是基于以往的服务端模板渲染的架构。这在2018年，未免有些过时和笨拙。我曾看过一个用Flask写的Todo项目，每个交互都要向服务端发送AJAX， 甚至连动态添加DOM元素都交由服务端渲染好再用jQuery添加。本系列文章，亦将由一个Todo App入手，实践前后端分离的架构，进而初窥全栈开发的门径。诚然，在前后端分离的系统中，Python作为后端并不是一个最优的选择（出门右转Golang）。但一则我热爱Python和Flask，二则别的我也不太会，所以我假定阅读本文的作者，已经看过[Flask的官方文档](http://flask.pocoo.org/docs/1.0/)，或[Miguel Grinberg的Flask Mega教程](https://blog.miguelgrinberg.com/post/the-flask-mega-tutorial-part-i-hello-world)。那么现在开始。
> 
> 本文项目地址: https://github.com/frostming/flask-vue-todo

## 前后端分离的思路

有人要问，我为什么要前后端分离？这个说起就话长了，网上也能搜索到一些解答，不过可简要概括为以下两点：

* 前端越来越重，很多页面交互，交由前端来实现会更加方便。我一直秉承：让专业的人做专业的事。这样事情会做得更漂亮。
* 前后端脱耦，可以分别交给两个人（团队）去做，且不会互相牵制。

那么哪些事是前端该做哪些是后端该做的呢？凡是涉及页面逻辑的部分，都是前端的工作，包括路由，渲染，页面事件等等。而只有在需要服务端的数据时，才给后端发请求。这样能大大节省网络带宽，减少网络延时的影响，一切交互都在本地，享受飞一般的感觉。特别是Todo App，你肯定不想每加一项，勾选一个完成都要busy一阵吧，哪怕就是10ms也是无法忍受，所以Todo App非常适合用前后端分离来实现。当然，Todo App也是各种前端框架的常见例子了，所以不太了解前端的各位Pythonista们，照着教程来一遍就差不多了，Flask的后端仅仅需要完成两个功能：

* 将内容持久化到服务器数据库
* 加入用户验证系统

## 建立Vue应用

我选用Vue.js作为前端框架，当然用React.js也是可以的，它们都有强大的工具链，但Vue.js的好处是它是中国人开发的，几乎所有官方库文档都有中文版哦，方便学习嘛，而且个人感觉Vue.js用起来也确实更爽一点。

### 目录结构

与传统的Flask app不同，前后端分离架构推荐静态文件（html, css, js们）和Python文件分开存放。目录结构如下：
```
flask-vue-todo
├─frontend    # 存放前端文件
├─backend    # 存放python文件
```

### 安装依赖

首先我们需要安装一键建立Vue项目的命令行工具`vue-cli`，安装方法（本文使用Yarn管理前端依赖，npm大同小异）：
```bash
yarn global add vue-cli
```
按照上述结构建立好项目之后，进入`frontend`目录，执行：
```bash
vue init webpack-simple
```
在一通眼花缭乱的进度条之后项目就建好了，执行`yarn run dev`看看效果吧。

## 编写Todo App

这一部分我不做重点介绍。此应用主要有以下逻辑：

* 输入内容按下回车时在Todo列表中加上一项
* 点Todo项前的checkbox将其标为完成
* 点Todo项的红叉将其删除
* 通过All, Undone, Completed过滤显示的Todo项

我使用了[Vuex](https://vuex.vuejs.org/zh)来管理应用的状态。注意把Ajax请求部分单独抽离到一个文件中方便管理，这时你可以先让它永远返回成功即可。为了符合之后即将使用的axios的API，可以这样写请求：
```javascript
// api/index.js
const mockTodos = [
  {id: 1, text: 'Item 1', done: false},
  {id: 2, text: 'Item 2', done: true}
]

const mockRequest = ()=>{
  return new Promise((resolve, reject)=>{
    setTimeout(()=>{
      Math.random() < 0.85 ? resolve(mockTodos) : reject(new Error("Get Todo list error!"))
    }, 100)
  })
}

const api = {
  getTodos() {
    return mockRequest('/todos')
  }
}
```

当然，我在应用中做了很多美化的工作让应用显得高大上，符合Vue.js的UI。

再次执行`yarn run dev`（若已执行则不必，它会自动热重载），你会看到编写完成的效果。`yarn run build`来编译已经写好的源文件。

## 编写Flask部分

好了，现在切换到`backend`目录，后端的应用预备作为一个API server来使用，为方便与前端交互，输入输出均采用JSON格式，Flask中可用`flask.jsonify`将结果转换成JSON的响应。告别看文档啃Stackoverflow爬坑，一切都是熟悉的味道，写起Flask来那还不上下翻飞？所有API请求都给它放到一个蓝图里，包含以下接口：

* 获取所有Todo项，包括它们的完成状态
* 更新Todo项
* 删除Todo项
* 新建Todo项

这根本就是数据库的增删查改嘛，用上`flask-sqlalchemy`简直不要太方便。其实这么简单的操作无需用SQL，用一个NonSQL数据库会更好，但为了部署Heroku，它提供免费的PostgreSQL数据库。主路由就简单了，只剩一个`index`了，因为页面路由都交给前端了嘛，这时我们的App就成了一个「单页应用」(SPA)了。
```python
@app.route('/')
def index():
    return render_template('index.html')
```
且慢，因为我们改换了目录结构，你必须告诉Flask静态文件和html文件的正确位置，编译好的静态文件在`frontend/dist`中，`index.html`在`frontend`中：
```python
FRONTEND_FOLDER = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'frontend')

def create_app():
    app = Flask(
        __name__, static_folder=os.path.join(FRONTEND_FOLDER, 'dist'),
        template_folder=FRONTEND_FOLDER
    )
    ...
```
对了，不要记得所有错误也都以JSON格式返回:
```python
from werkzeug.exceptions import HTTPException

@app.errorhandler(HTTPException)
def handle_http_error(exc):
    return jsonify({'status': 'error', 'description': exc.description}), exc.code
```
好了，现在可以把前端部分中之前伪造的请求换成真的了，我就用的Vue.js推荐的[axios](https://github.com/axios/axios)，需要初始化一下，把所有请求变成JSON请求：
```javascript
import axios from 'axios'

const api = axios.create({
  headers: {
    'Content-Type': 'application/json'
  }
})
```
赶紧运行`FLASK_ENV=development flask run`吧，然后你就能从<http://localhost:5000>看到效果了。

## 关于前端开发服务器和后端开发服务器

可能有的同学已经注意到了，前端和后端都有一个开发服务器，但默认端口号不同，一个是8080，一个是5000。其中8080的开发服务器是调试前端页面用的，它仅仅包含静态文件，这时后端API是不可用状态的。但它有很多方便调试的功能，比如详尽的错误信息和热重载，编写前端时，用这个就够了，但API请求需要弄成假的。

而5000端口的服务器是Flask提供的，启用了`FLASK_ENV=development`可以打开Flask的`DEBUG`模式。它也能访问主页，但那是前端已经编译好的，不支持热重载哦。当然，Flask支持Python文件热重载，现在知道专业的人干专业的事的道理了吧。区别总结如下：

|   | localhost:8080 | localhost:5000 |
| --- | ------------- | --------------- |
| 能访问页面？ | 是 | 是 |
| 能访问API？ | 否 | 是 |
| 热重载 | HTML/CSS/Javascript | Python |
| 更新静态文件 | 刷新生效 | 先`yarn run build`，再强制刷新 |

还有，这两个服务器，都不能在生产环境使用哦。那么，能否同时获取这两个服务器的好处呢？当然是可以了，同时启动两个服务器，然后把Flask启动的那个5000服务器单纯作为API服务器，从8080端口访问页面。这时，API请求的URL就与当前地址不同了，需要显式配置请求URL到5000端口：
```javascript
...
const api = axios.create({
  baseURL: 'http://localhost:5000',
  headers: {
    'Content-Type': 'application/json'
  }
})
```

好，到现在为止，我们已经成功运行了一个可以持久化到服务器数据库的Todo App，下篇文章我们将会加入更多功能，使得App更加像样。