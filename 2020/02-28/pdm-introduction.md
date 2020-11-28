---
category: 编程
date: 2020-02-28 05:56:16.271251
description: 自己的轮子，自己做主
image: https://images.unsplash.com/photo-1512418490979-92798cec1380?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1350&q=80
tags:
- Python
- Packaging
template: post
title: PDM - 一款新的 Python 包管理器
---

去年临近跨年的某一天，一个包管理器突然在脑海中形成了蓝图。粗略地估计了一下我的编码能力，我认为这在我的能力范围之内，于是尽管年底非常忙，还要忙着晋升答辩的事情，我还是腾出空（摸鱼）写下了我的第一行代码。
<!--more-->
![image-20200228135957046](https://static.frostming.com/images/image-20200228135957046.png)

这个项目就是[pdm](https://github.com/frostming/pdm)，我给它取了一个很装逼的名字——Python Development Master。截止发文时，已经在PyPI上发布了0.3.0版本，它包含以下特性：

- PEP 582 本地项目库目录，支持安装与运行命令，**完全不需要虚拟环境**。
- 一个简单且相对快速的依赖解析器，特别是对于大的二进制包发布。
- 兼容 PEP 517 的构建后端，用于构建发布包(源码格式与 wheel 格式)

做一个项目，首先自己要用起来，至少对我来说，这些功能非常Exciting，而且我随时可以根据自己的喜欢做新功能（P.S. 是的，当Pipenv的维护人却没有什么权限发布新版这太让人沮丧了）。如果你对这个新工具也感兴趣，可以访问[官方文档](https://frostming.github.io/pdm/)或是GitHub主页。



不如就多说一些别的吧，当做是我开发这个项目的碎碎念。

## 把握造轮子的程度

造轮子造轮子，造法也有很多种，你可以从零件厂采购轮毂，轮胎，自己组装，也可以从冶金、找橡胶树资源开始。

### 1. 整体引用

前一种方法，省事，相当于你只把内部的组件打乱重组，包装成一个新的样子出来。Pipenv即属此类，它其实是由pip(安装器)，virtualenv(虚拟环境)，pip-tools(依赖解析)几大部分组合而成，连接调度的方式居然是通过subprocess call，所以这里面子进程启动、输出结果解析，都是耗时的。其余的次要组件，包括依赖树显示、依赖安全性检查等，无一例外都是通过内嵌别的库实现的。这种方法，很懒，引用作者Kenneth Reitz本人的话，叫做**I (re)design beautiful APIs**。其中一大缺点，就是要做什么bug修复、feature引入，非常依赖上游库的更新，要不就是有很重的vendor系统，非常不自由。

比如我要安装一个包，用这种方法实现出来是这个样子:

```python
def install_requirement(requirement):
    # requirement是符合PEP508规范的依赖格式
    subprocess.check_call([pip_path, "install", "--no-deps", requirement])
```


### 2. 使用内部API

当你对于上游库的修改多到了一定程度，你一气之下，决定化整为零，把依赖的库拆散，只取它内部的结构和接口来做。还是同样的功能，用pip内部的API实现起来，是这个样子的：

```python
def install_requirement(requirement):
    from pip._internal.req.constructors import install_req_from_line
    
    ireq = install_req_from_line(requirement)
    ireq.install(["--no-deps"])
```

看看那一串长长的import string，人家都叫做`internal`还带下划线了，都挡不住你要从里面import。这就是这种方法的问题所在了：**不稳定**。可能下个版本，pip就升级了，API会变得完全不同，那么你就要做相应的改变。


### 3. 自己动手，丰衣足食

你改了几个版本以后，心里暗骂了一句pip的祖宗，责怪它为什么老改API，一怒之下全部推倒重来，不求别人，全都自己实现，于是这一版代码变成了这样：

```python
def install_requirement(requirement):
    req = parse_install_requirement(requirement)
    download_artifact(req)
    if not req.is_wheel:
        unpack_artifact(req)
        build_wheel(req)
    copy_modules(req)
    install_scripts(req)
```

我省略了很多代码，这里的每一个函数，背后都是几十上百行的代码，因为requirement的类型是很多的，有本地的文件、有Git的地址，有的带marker，有的带extras……你要覆盖到这所有的情况，难免出bug。这时就体现出用第三方库的优点来了：它们可能已经帮你把所有的bug都踩过了，并受过生产环境中的考验。

所以造轮子要用哪种方法来造，是要经过仔细的考量的。用了第一种，结果发现需要定制很多；用了第三种方法，结果发现天天都在修bug。我在开发PDM初始，基于对个人精力的评估，选择的是第二种方法，尽管我有一万次想丢掉pip这个包袱。

## 选择合适的mock策略

测试的时候往往会依赖一些外部的服务，而这些外部服务有可能1）不可用；2）和你的代码正确性无关。这种情况下就需要mock技术，测试和mock说起来话就长了，够写一本书，我就挑一个具体的场景来说。

测试一个包管理器，PyPI是一个最重要的外部服务。Pipenv使用的技术是模拟了一个[本地的PyPI服务器](https://pypi.org/project/pytest-pypi/)，实现了PyPI的接口，然后把所有指向PyPI的请求改为本地的PyPI服务。这种方法对测试代码的侵入是非常小的，你甚至只需要修改PyPI的URL为`https://127.0.0.1:{port}/simple`就可以了。但这依然要求服务器上的文件在[本地也有](https://github.com/sarugaku/pipenv-test-artifacts)。这会带来额外的负担，也会拖慢测试执行的速度。现在Pipenv跑一遍完整的测试需要45 min，请问谁受得了？

![image-20200228145339946](https://static.frostming.com/images/image-20200228151636323.png)

如上图所示，`find_matches(requirement)`的作用是根据给定的依赖去PyPI上寻找符合条件的安装包。它会去PyPI的`/simple/<package>`端点获取所有链接地址，然后封装成对象返回。其实测试这个接口，并不需要一个PyPI服务器，更不需要真实的安装包文件，你只需要保证返回的结果里包含你想要的数据即可。所以PDM拦截了这个请求，转而从一个JSON文件中取数据返回。这大大的加快了测试的速度。



又比如，我要测试一个获取远程文件的接口，它通过`requests.get(url)`去获取文件内容并下载到本地。测试时完全可以把这个文件放在本地，然后请求时读取这个文件内容即可，下面是一个把requests请求mock掉的方法：

```python
class LocalFileAdapter(requests.adapters.BaseAdapter):
    def __init__(self, base_path):
        super().__init__()
        self.base_path = base_path
        self._opened_files = []

    def send(
        self, request, stream=False, timeout=None, verify=True, cert=None, proxies=None
    ):
        file_path = self.base_path / urlparse(request.url).path.lstrip(
            "/"
        )  # type: Path
        response = requests.models.Response()
        response.request = request
        if not file_path.exists():
            response.status_code = 404
            response.reason = "Not Found"
            response.raw = BytesIO(b"Not Found")
        else:
            response.status_code = 200
            response.reason = "OK"
            response.raw = file_path.open("rb")
        self._opened_files.append(response.raw)
        return response

    def close(self):
        for fp in self._opened_files:
            fp.close()
        self._opened_files.clear()
        
# 使用
session = requests.Session()
session.mount('http://fake-url.org', LocalFileAdapter(Path('./fixtures')))
```

这个例子中是通过mock `Adapter.send()`方法实现的，这是一个相当底层的接口，所有经过`http://fake-url.org`的请求都一定会通过这个方法。你当然可以通过mock`response.get_content()`实现相同的效果，但你无法保证上游调用者一定是调用这个方法。**mock得越底层，能使得你的mock适用范围越广。**

