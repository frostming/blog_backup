---
author: Frost Ming
category: 编程
date: 2019-11-22 13:30:42.178764
description: ''
image: https://images.unsplash.com/photo-1421882046699-09a0ff4ffb1b?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1391&q=80
tags:
- Python
- 博客
- Flask
title: 使用 Flask 做一个评论系统
---

因为我博客使用的Disqus代理服务下线，博客的评论系统可能有一阵子没有工作了。惭愧的是我竟然最近才发现，我的工作环境一直是没有GFW存在的，发现是因为有个朋友为了留言给我不惜通过赞赏1元钱的方式。赞赏功能也是我最近才上的功能，但我怎么是这么一个无良的博主呢，我认为一个好的评论交流环境还是非常有必要的。但是自建评论还是换用其他墙内友好的评论系统，我还是纠结了一阵的，大致上我有这么几个要求：

1. 主要服务墙内，Disqus虽香但墙内用不了啊
2. 颜值，要能匹配当前博客的主色调，或者能方便地自定义皮肤
3. 评论要支持markdown语法
4. 评论数据要有地方可管理、归档、导入导出等
5. 外部用户使用评论的门槛要低
6. 用户收到回复时能通过他「常用的」联系方式收到通知

评论系统大致有这么几个选择方向：一是使用类似Disqus这样的三方平台，这样数据托管不用操心，但服务随时有挂掉的风险，而且外观上也不够自由；二是使用Github Issue作为后端的评论系统，比如[Gitment](https://github.com/imsun/gitment)，[utterances](https://utteranc.es/) 好处是你不必担心Github挂掉，而且不用收钱。但不方便后续打包迁移，而且我一直反对**过度利用**Github；那么剩下的选择就是自己撸一个了，简单的构思评估以后我列出以下列[功能大纲](https://github.com/frostming/Flog/issues/18)：

- 评论数据模型
- 评论展示
- 评论管理
- 导入disqus评论
- 新评论通知
- 第三方登录
- 评论导出（低优先）

类比Workpress提供的评论功能，用户只需要填用户姓名和电子邮件这两个信息就够了，前者用来显示作者名，后者用来接收通知，个人网站用来推广自己，但不是必填的。我在这个基础上，希望增加第三方登录的功能，这样用户就不用填写这些信息，点一个按钮就好了。关于第三方登录的开发实现，我会留到下一篇文章中。

## 评论数据模型
首先是评论数据模型的设计，我的理念是够用就好，不用太多太复杂的东西，毕竟我的文章平均0.2条评论。所以，点赞什么的就不要了，评论删除直接删数据就好了，也不需要什么状态。

![comment_uml.png](//static.frostming.com/images/2019-11-comment_uml.png)

其中分别有一个外键指向作者用户以及文章记录，User里面会记录这个用户的Email, 名称，头像信息。另外会有一个parent_id指向评论回复的对象（也是一条评论），这里有一个指向自身的外键，使用`Flask-SQLAlchemy`写起来是这样的：

```python
class Comment(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    post_id = db.Column(db.Integer, db.ForeignKey("post.id"))
    author_id = db.Column(db.Integer, db.ForeignKey("user.id"))
    floor = db.Column(db.Integer)
    content = db.Column(db.Text())
    html = db.Column(db.Text())
    create_at = db.Column(db.DateTime(), default=datetime.utcnow)
    parent_id = db.Column(db.Integer, db.ForeignKey("comment.id"))
    replies = db.relationship(
        "Comment", backref=db.backref("parent", remote_side=[id]), lazy="dynamic"
    )

    __table_args__ = (db.UniqueConstraint("post_id", "floor", name="_post_floor"),)
```

`floor`表明评论是「第几楼」，注意这里有个限制，每篇文章楼层不能重复。

## 评论展示

接下来看看如何展示评论。每条评论都可能有若干回复，回复评论又有回复，所以这是一个树形的结构，最极端的，如果把所有树形都嵌套显示出来，就会像网易新闻评论盖楼那样。另一个极端，是把所有评论都展平，按回复时间排序显示，这样又会失去回复的上下文信息。还是那句话，够用就好，我选择了一条折中的方式：两层树形展示。直接评论的是第一层节点，然后回复这些评论的，和回复这些回复的，都展平成一层节点，算作这条评论的子节点。外层评论和子节点都按时间排序显示，但只有外层评论具有楼层属性。且子节点应该展示回复的是哪位作者，这样就大大减小了上下文混淆的可能（虽然我觉得我这评论的量，全显示成一层也不会怎样）。

评论框编辑器使用的是[simple-mde](https://github.com/sparksuite/simplemde-markdown-editor)，使用起来非常简单：
```html
<link rel="stylesheet" href="https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.css">
<script src="https://cdn.jsdelivr.net/simplemde/latest/simplemde.min.js"></script>
...
<textarea name="content"></textarea>
...
<script>
var simplemde = new SimpleMDE();
</script>
```
完事！后续可能会考虑加上emoji选择器。markdown保存，后端渲染html，前端取出展示。最后结果非常漂亮令我满意，大家可以在本篇文章下面看到效果。

## 评论管理

对应的，在管理员页面也加上一个评论管理页面，以及开启内置评论的开关。因为最初设计的是评论一经发出，只能删除，不能修改，所以这种页面对我这样的CRUD程序员来说不在话下。

现在就到了激动人心的时刻了，把Disqus的评论数据迁移过来！我到Disqus页面上去看，发现Disqus支持导出评论数据为特定的结构，是一个xml，只要是结构化的数据，那就问题不大了。主要分为两个部分，前半部分是thread的列表，表示有哪些文章开启了Disqus的评论，包含文章的url等信息（取决于你如何开启的Disqus），后半部分是评论列表，每条评论有评论内容、作者信息、回复的上级评论ID，还好数据模型设计得好，这些都在射程范围内。于是写了一个函数解析，导入这些数据，注意有些已删除的或者垃圾评论直接过滤掉即可，函数放在[这里](https://github.com/frostming/Flog/blob/0620874d9080cfd0748007d189ae8649449ff560/flaskblog/api/views.py#L321)了。

![disqus_export.png](//static.frostming.com/images/2019-11-disqus_export.png)

上传文件，导入，成功，Disqus的评论就完美迁移过来了！

## 评论通知

评论通知需要拿到用户的联系方式，所以表单中电子邮件是必填的，接入第三方登录时，我也要考虑哪些服务是可以获得联系方式的，目前决定是用Github，Google两种方式，至于新浪微博，虽然国人常用，但好像没有谁会在微博上留联系方式，所以排除，微信倒是很好，但微信的第三方登录好像很麻烦的样子，暂不考虑。所以最后就是邮件通知。那就简单了，用Flask的扩展[Flask-Mail](https://pythonhosted.org/Flask-Mail/)全都搞定，但在使用中我遇到两个坑：

1. 如果在后台任务中做发送邮件的操作，注意获取`g`对象需要应用上下文，获取请求信息需要请求上下文，而光用Flask提供的`copy_current_request_context`只复制请求上下文，而会创建新的应用上下文，我写了两个函数，一个是添加应用和请求上下文到一个函数，另一个是将函数转换成后台任务:

 ```python
 def with_app_context(f):
    ctx = _app_ctx_stack.top
    req_ctx = _request_ctx_stack.top.copy()

    def wrapper(*args, **kwargs):
        with ctx:
            with req_ctx:
                return f(*args, **kwargs)
    return update_wrapper(wrapper, f)


def background_task(f):
    def wrapper(*args, **kwargs):
        future = gevent.spawn(with_app_context(f), *args, **kwargs)

        def callback(result):
            exc = result.exception
            current_app.log_exception((type(exc), exc, exc.__traceback__))

        future.link_exception(with_app_context(callback))
        return future

    return update_wrapper(wrapper, f)
```
这里后台任务用了gevent，如果用线程方式，则改成
```python
from concurrent.futures import ThreadPoolExecutor

def background_task(f):
    def wrapper(*args, **kwargs):
        with ThreadPoolExecutor() as pool:
            future = pool.submit(with_app_context(f), *args, **kwargs)

        def callback(result):
            exc = result.exception()
            if exc is not None:
                current_app.log_exception((type(exc), exc, exc.__traceback__))

        future.add_done_callback(with_app_context(callback))
        return future

    return update_wrapper(wrapper, f)
```

2. 腾讯云的主机默认禁掉了25端口，害我找了半天原因，只要自己在控制台解禁一下即可立刻生效。

## 参考链接

* 源码仓库: https://github.com/frostming/Flog
* [Implementing User Comments with SQLAlchemy - miguelgrinberg.com](https://blog.miguelgrinberg.com/post/implementing-user-comments-with-sqlalchemy)