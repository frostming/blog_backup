---
category: 编程
date: 2020-03-16 04:50:49.433635
description: 可选配的插件
image: https://images.unsplash.com/photo-1562369083-4ff96958f868?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1363&q=80
tags:
- Python
- Flask
- django
template: post
title: 浅谈 Python 库的插件系统设计
---

插件(Plug-in)，扩展(Extension)或增件(Addon)，都差不多指的是一个东西：为一个已有软件增添额外功能的组件。给软件设计一个易用和强大的插件系统，能让你的软件寿命更长，让整个社区来共同建设，符合开源的精神。

<!--more-->

上周末我给[PDM](https://github.com/frostming/pdm.git)实现了一个插件系统，于是就顺便利用这篇文章总结一下Python库里面用到的插件系统的设计方法。大体说来，插件分两种类型：
1. 安装了以后需要写配置、写代码让插件生效——我称之为可选配的插件
2. 安装了以后插件功能即生效，或者程序运行时自动生效——我称之为安装即生效的插件

下面我会分别对这两种类型，结合一些项目的例子来说明。

## 可选配的插件

可选配的插件一般用在Python库中[^1]，特点是可配置，可调整插件参数，但需要写额外的代码或配置来装载它。

[^1]: Python库(Library)是针对Python应用(Application)而言的，前者主要用来import，发布到PyPI上，后者主要是用来run，一般不发布到PyPI上。

### Requests

作为Python中最著名的库没有之一，Requests的层级划分和模块解耦做得非常好。这样开发者想在上面做二次开发非常容易，有种随心所欲的感觉。主要的扩展点有：

- 如果想自定义网关、请求处理的方式，自定义一个类继承`requests.adapters.BaseAdapter`。这个类的实例可以通过`session.mount(prefix, adapter)`加载到`session`中。比如[requests-wsgi-adapter](https://pypi.org/project/requests-wsgi-adapter/)就把请求发给了WSGI应用，而不是Internet地址。
- 如果想自定义请求认证的方式，自定义一个类继承`requests.auth.AuthBase`。这个类的实例可以直接传给`session`API的`auth=`参数。
- 如果只是想修改返回的响应，可以增加`response`钩子函数，赋给`session.hooks`属性。
- 如果想封装一系列的操作，包括Cookie、认证、响应处理等，可以自定义一个`Session`类继承`requests.Session`，比如[Requests-OAuthlib](https://requests-oauthlib.readthedocs.io/en/latest/)。

### Flask
>Flask说：「本框架什么功能也没有，你上GitHub上找啊，那里的扩展又多，说话又好听，只有靠扩展才能勉强生活这样子。」

所以Flask的插件系统设计也是相当优秀的，所有的扩展点都收拢到了`flask.Flask`app对象上，扩展中只用接受到这个对象，然后对它进行一顿改造就完了。一些扩展点有：

- 绑定一个视图蓝图：`app.register_blueprint()`
- 请求前、请求后钩子：`@app.before_request`, `@app.after_request`
- 信号钩子：`flask.signals`模块
- 模板过滤器、模板全局函数、变量：`@app.context_processor`, `@app.template_filter`
- 错误处理器：`@app.errorhandler`

只要里面提供的扩展点，都可以打包在一个扩展中统一对外提供，唯一缺失的就是DB model，导致Flask扩展不能包含db model，这是一个很大的限制。

### Django

Django在扩展方便性上比Flask差一些，但它的插件模块自治性非常好。因为Django是以app为单位进行组织的，模板、静态文件、数据库模型、admin视图，测试，都可以包含在一个app中，不依赖外部的组件。这样一个app就可以单独分拆出来到处使用。但是如果插件中有包含middleware, logging处理这些东西，用户还是要单独在`settings.py`中配置，不是很方便，而且插件也必须深度绑定Django。

### Marko

[Marko](https://github.com/frostming/marko)是我自己写的一个CommonMark的parser和renderer。众所周知CommonMark是个spec极度变态的Markdown标准，它的parser没办法用BNF+AST的方法来实现。几乎所有的CommonMark库（甚至Markdown库）都是穷举所有元素类型，为他们分别编写parse函数和render函数来实现。我在做Marko之初，就希望它是一个比较容易扩展的Markdown库，用户能扩展：

- 修改已有元素的解析方法
- 修改已有元素的渲染方法
- 增加新的自定义元素类型

并能把这一坨聚合在一个包里发出。

在介绍Marko的插件系统前，我们先看看[Python-Markdown](https://github.com/Python-Markdown/markdown/)的扩展方法

#### Python-Markdown 的扩展方法

我猜没有人给这货写过扩展吧，它的官方文档，几乎什么也没写，要研究怎么写扩展，得去看源码（从例子中学习）。经过一番抓头，得出大致有这么几个扩展点

- `Preprocessor` 先扫描一遍文档，元素的解析要在这里做
- `InlineParser`, `BlockParser` ，修改解析得到的inline元素和block元素
- `Treeprocessor`，渲染AST

最抓头的是所有解析都得手写正则，还有各种回溯机制，相当反人类。

#### Marko 的扩展方法

这里先说下Markdown的模块划分，所有元素的匹配和解析方法，包括块级元素和行内元素，都被封装在各自的元素类中，然后所有元素类都会被加载到Parser类中进行解析。得到一个AST以后再喂给Renderer类，Renderer类中对于每种元素都有一个对应的render方法，把所有render的结果字符串拼接起来就得到了最终渲染的结果。

所以这里主要的扩展操作就是类的继承、替换，加上考虑到多个扩展想继承同一个类，为避免相互覆盖，我采用了基于Mixin的方式：

- 对于元素，自定义元素类
- 对于parser，定义一个`ParserMixin`类实现自定义解析
- 对于renderer, 定义一个`RendererMixin`类实现自定义render方法

最后把这三者都组装在一个对象中：
```python

class MyExtension:
    elements = [...]
    parser_mixins = [ParserMixin]
    renderer_mixins = [RendererMixin]
```
在入口出通过和`Python-Markdown`相似的`extensions=[MyExtension]`读入扩展对象，将这三个属性取出，合成最终的parser和renderer:
```python
self.parser = type("Parser", bases=("BaseParser",) + tuple(ext.parser_mixins))
self.parser.add_elements(ext.elements)
self.renderer = type("Renderer", bases=("HTMLRenderer",) + tuple(ext.renderer_mixins))
```