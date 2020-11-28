---
category: 编程
date: 2018-09-14 02:31:14.787378
description: 从pip到virtualenv到pipenv
image: //static.frostming.com/images/2018-09-pipenv.jpg
tags:
- Python
- Packaging
template: post
title: Python包管理工作流
---

>凡是一个成熟的软件生态都有它的软件源和对应的包管理工具，Python也不例外，pip就是它的（官方推荐的）包管理工具。可能很多小伙伴都对pip比较熟悉了，那么使用pip会有什么问题呢？

## 使用requirements.txt管理依赖
pip最普通的使用方法就是`pip install <package_name>`，如果要指定版本，可以用`pip install <package_name>==<version>`。如果你的应用中包含很多条依赖，可以把这些依赖都写在一个`requirements.txt`文件中，就像这样：
```
Django==1.11.2
requests>=2.11.0
simplejson
ordereddict
```
 其中既有指定版本号的，也有忽略版本号的。然后你就可以用：`pip install -r requirements.txt`来安装所有依赖。`requirements.txt`本质上是一个纯文本文件，但它还支持其他特性，比如包含另一个`requirements.txt`，这就使得模块化成为可能：
```
-r web.txt
-r secure.txt
simplejson
ordereddict
```
 有了内部PyPI镜像，安装依赖将会变得非常简单。那么问题来了：如果我想要升级依赖的版本呢？

对于忽略版本号的依赖，当然没问题，全新安装时，自动会选择当前最新版本，但对于指定了版本号的，则需要手动更新这些版本号，然后重新安装。

## 使用虚拟环境
现在升级好了，一运行，你发现其他服务挂了，这是因为其他服务可能不兼容新版的依赖。这非常有可能发生，A应用依赖v1.0，B应用依赖v2.0，你一升级，A就用不了了。如果把A应用和B应用环境独立，装两份不同版本的依赖，不就没问题了？没错，要达成这一目的，你可以装两份Python，然后分别使用Python下的pip安装，就会安装到不同路径，运行应用时，指定不同的Python路径就可以了。但这样未免太过烦琐，于是virtualenv大展身手的时机来了。

Virtulenv会使用当前的Python解释器创建出一个虚拟环境，并把Python解释器拷贝一份到环境中，这个拷贝，比起编译安装一个新的会省不少资源。使用时，需要事先激活这个虚拟环境，把当前的Python指到这个环境中的Python：

### 创建虚拟环境
```
$ virtualenv venv
...
$ cd venv
```
### 激活环境
```
$ source venv/bin/activate
(venv)$ 
```
后续的pip安装、启动应用，只要在这个虚拟环境中运行即可。也可以不激活，通过绝对路径使用它：
```
$ /home/frostming/myproject/venv/bin/python server.py
```

## Pipenv: pip + virtualenv

有了虚拟环境，依赖冲突的问题解决了，但还有一个问题仍未解决：更新版本号，如果你想更新依赖包，对于那些在`requirements.txt`中指定了版本号的依赖，你得逐个检查是否有新版，然后更新。既然如此麻烦，那是不是全都忽略版本号就好了？非也，这会产生新的问题。你在开发机上验证完毕了，部署到生产机上，或者别的小伙伴喜欢这个应用，想在自己的机器上跑。这时使用无版本号的`requirements.txt`安装依赖，很可能安装的版本和你开发时不一样，结果导致应用不可用。

但仔细分析，`requirements.txt`中是否指定版本号，解决的是两个维度的问题：

* 无版本号是为了方便你更新依赖时自动拉取最新版本。（A型）
* 有版本号是为了部署和开发时的环境完全一致。（B型）

但`requirements.txt`只有一份，手动维护两份`requirements`成本又过高。于是Pipenv就应运而生，它可以从A型的`requirements.txt`（Pipenv使用了一种新的格式Pipfile）生成B型的文件，称为Pipfile.lock，锁定当前所有依赖的版本。部署时，从Pipfile.lock安装，这些理念，是从其他语言的包管理工具借鉴过来的。

除此之外，Pipenv还会帮你管理虚拟环境，不用自己创建。

Pipenv的一些主要的使用方法：

1. `pipenv --two/--three`：使用Python 2或Python 3创建一个虚拟环境并新建Pipfile，它会探测系统中安装的所有Python并自动选择对应的Python版本。
2. `pipenv install`：从当前的Pipfile安装所有依赖
3. `pipenv install --deploy`：从Pipfile.lock安装所有依赖，部署用
4. `pipenv lock`：从当前的Pipfile生成Pipfile.lock
5. `pipenv install <package_name>`：安装新的依赖包、添加到Pipfile中，并lock
6. `pipenv update`：使用最新可用版本更新Pipfile.lock并安装
7. `pipenv shell`：激活虚拟环境的shell
8. `pipenv run <command>`：在不激活虚拟环境时运行虚拟环境中的命令

其他用法参考文档：https://docs.pipenv.org/