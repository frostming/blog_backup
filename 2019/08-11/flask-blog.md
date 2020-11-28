---
category: 编程
date: 2019-08-11 06:00:21.587857
description: ''
image: //static.frostming.com/images/2019-08-blog.png
tags:
- Python
- 博客
- Flask
template: post
title: 使用Flask搭建个人博客
---

我的个人博客从Hexo迁移到自建主机，主要是为了能自由的增减特性，和随时随地的更新博客（然而并没有）。所以考虑用Python的Web框架来写，由于我最开始是从Flask入门的，对它的源码也最了解，所以就选择了Flask。总的来说，一个个人博客网站，主要包含以下几个功能：

1. 文章的保存和展示
2. 文章的分类和标签
3. 文章的评论管理
4. 对于动态博客来说，还有博客的后台部分

其中第4部分已经有[单独的文章](/2019/04-24/new-admin)来介绍，使用的是前后端分离的方式访问API。而第3部分我暂时打算用第三方的评论系统来管理（毕竟造个轮子也没有别人强大）。至于文章编写，我当然是选用Markdown。

## 代码结构

使用Flask来写博客，首先要考虑的是项目结构——它不像Django一样，有固定的推荐结构，而是给了用户很大的自由空间来组织项目的代码，总的来说，有两大流派：

1. 按业务划分，有点类似于Django APP的组织方式，我们会有post, auth, user, comment等部分。
2. 按模块划分，分成操作数据库的models部分，渲染视图的views部分，处理模板的部分等等。

由于去掉了评论系统以后，博客的功能还是比较简单的，就是文章、分类、标签的管理，所以我使用了第二种组织方式，下面是我的代码结构：
```
flaskblog
├── __init__.py
├── admin.py
├── api             # API路由
├── app.py          # app对象
├── babel.cfg
├── cli.py          # app命令行
├── config.py       # 配置
├── md              # markdown解析器
├── models.py       # 数据库模型
├── templates       # HTML模板
├── templating.py   # 模板处理函数
├── translations    # 翻译文件
├── utils.py        # 通用函数
└── views.py        # 视图函数
```

## Flask扩展

用Flask来写Web，最重要的是选用恰当合适的扩展。因为扩展质量良莠不齐，加上有些扩展很久不维护了，以往有很多其他文章中推荐的扩展，其实都不需要了（基于Flask 1.0+版本），本着最小使用的原则，下面是我博客中用到的扩展：

* Flask-Login处理用户登录
* 操作数据库的ORM和迁移必备组合Flask-SQLAlchemy和Flask-Migrate
* Flask-Whooshee搜索索引
* Flask-Moment本地化时间（因为时间统一以UTC时间保存）
* Flask-Assets处理静态文件
* Flask-Babel国际化

由于后台部分是只有API的，而博客展示部分又没有表单，所以Flask-WTF，Flask-Bootstrap这些都不需要了，但Flask-Login还是要用来做后端用户态管理；Flask-Scripts的功能已经[内置到Flask中](https://flask.palletsprojects.com/en/1.1.x/cli/)了，所以推荐大家都弃用掉这个扩展。Flask-Assets主要用来Minify CSS和JS文件，它会自动在静态文件的URL中加上一个独特的后缀，这样不用更新静态文件后每次清除缓存。

## Markdown渲染

在Python的世界中已经有很多Markdown的解析器，但它们要么有时输出不符合预期（mistune），要么自己写起扩展功能来非常痛苦（python-markdown, python-markdown2），所以我一怒之下自己造了个轮子[Marko](https://github.com/frostming/marko)，它默认符合CommonMark规范且自带GFM支持，还内置提供三个常用的扩展：脚注、目录生成、及中英文之间插入空格，欢迎大家提PR实现更多扩展。在博客项目中，我又利用Marko的扩展机制进行了进一步的定制：图片排版功能。使用方法是将多个图片放在一起（不换行），将渲染为多列图片。例：
```
![](//static.frostming.com/images/image1.jpg) ![](//static.frostming.com/images/image2.jpg)
![](//static.frostming.com/images/image3.jpg) ![](//static.frostming.com/images/image4.jpg)
```
渲染效果：

![](https://github.com/frostming/Flog/raw/master/resources/sample_images.png)

## 博客源码

更多实现细节可以参阅我已公开到Github上的[源码](https://github.com/frostming/Flog)。