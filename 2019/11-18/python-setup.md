---
category: 编程
date: 2019-11-18 09:42:47.036853
description: 2020年我使用的Python工具
image: https://images.unsplash.com/photo-1573937938551-ad632716c1b8?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1350&q=80
tags:
- Python
- Packaging
template: post
title: 我的Python环境设置
---

网上看到一篇[博文](https://jacobian.org/2019/nov/11/python-environment-2020/)，我突然也想写一下自己正在使用的Python环境设置，以及对应的工具链。众众众所周知，Python环境管理是个很大很大的坑，坑里面有无数新人or老司机的尸体。而Python环境管理的工具又五花八门，所以可能每个人的设置都不尽相同。我列出的我使用的工具链，至少最大地满足了自己的需求，但不一定满足所有人的需求。但我自认为在Python环境管理方面颇有心得，所以有一定的参考价值。

## 我的需求
照例列一下我的需求：

1. 我平时在三种不同的环境中使用Python，除了公司项目规定使用Python 3.6以外，个人项目都是尽可能用最新版：
    1. Python 3.6.8 + Linux（公司，公司项目）
    2. Python latest + Windows（公司，个人项目）
    3. Python latest + MacOS（在家，个人项目）

2. 我同时工作在多个项目上，所以隔离环境非常重要
3. 除非非常必要，否则不用docker
4. 我用到很多Python 的命令行工具：black, twine, ...
5. 系统上保留的Python数量尽可能少，但我绝不会干升级系统Python这种事的，所有系统Python是什么就是什么，我不会去碰它

## 使用的工具

### 1. Python版本管理: [PythonUp](https://github.com/uranusjr/pythonup-posix)(posix), None(Windows)

**为何不是pyenv?**

`pyenv` 把所有Python版本都分开安装，就算是patch release。这样做可以最大可能地保证你机器上的所有虚拟环境、命令行程序都是可用的，但我会嫌python的版本太多了，毕竟99.99%的情况下，Python 3.7.4都可以平滑**替换**为Python 3.7.5而不造成任何损失。

`PythonUp`就是这样一个工具，它同时支持posix + windows平台。你可以把它看成是`pyenv`的简化版，但它是支持minor release层面隔离的，如果只是patch release升级是直接替换的。使用方法很简单：
```
$ pythonup install 3.6
$ pythonup install 3.8
$ pythonup use 3.8
$ python3 --version
Python 3.8.0
```
但要注意它相比`pyenv`要少一些功能：

* 自动激活local python版本
* 管理虚拟环境
* 全局解释器名称为`python3`，`pip3`而不是`python`，`pip`

**Windows呢?**

我在Windows上没有用任何工具管理Python版本，因为Python的Windows安装器本身就支持替换升级（patch update），而且全局的Python命令行程序不会受到任何影响。而且Windows上的Python 3自带一个`py`的版本启动器，可以方便地选择运行的Python:
```
> py -2 --version
Python 2.7.15
> py -3 --version
Python 3.8.0
```
所以我基本也不用切换python版本了（`py -3` 运行起来比`python`还短些）

### 2. 安装命令行程序: [pipx](https://pypi.org/project/pipx/)

把命令行程序安装在隔离的环境中，不会搞乱依赖。原来有一个工具叫[`pipsi`](https://pypi.org/project/pipsi)但它停止维护了，`pipx`是活跃状态而且更加好用，强烈推荐！使用起来也很简单，只需要在原来`pip install`安装的基础上加一个`x`就可以了：

```
$ pipx install black
```

### 3. 虚拟环境、依赖管理：[Pipenv](https://github.com/pypa/pipenv.git)@master分支 + virtualenv魔改版

**master分支**

Pipenv被诟病最多的就是已经近一年没有新版发布了，使用Github上的master分支完美解决这个问题，嘿嘿，几个月使用来看，bug已经相当少了。

**virtualenv魔改了什么?**

Pipenv是使用`virtualenv`来创建虚拟环境的，但`virtualenv`有几个重大缺陷，大到我忍不了所以搞了个[fork](https://github.com/frostming/virtualenv-venv)
1. virtualenv中的python无法再创建虚拟环境
2. virtualenv指向的python升级则环境变成broken状态

而Python 3自带的venv能解决这些问题，不明白为什么virtualenv还不支持venv，我只能fork一下使得virtualenv尽可能使用python3自带的venv来创建虚拟环境。
使用`virtualenv`魔改版替换原版：
```bash
$ pip install -I https://github.com/frostming/virtualenv-venv/releases/download/16.4.4-fork/virtualenv-16.2.0_fork-py2.py3-none-any.whl
```
fork版本的更新并不能跟上上游的更新，主要也是因为没碰到什么bug且目前只有我自己在用。

**Poetry呢**

Poetry确实也相当好用且有越来越多的人从Pipenv切换过去，但对我来说Poetry没解决这两个问题之前我不会切过去（也可能已经改进了，有一段时间没用过）：

1. 更多的虚拟环境的管理：清理，删除，查看
2. poetry的`pyproject.toml`还不是标准，配置文件格式还有许多问题（C扩展定义、markers支持等），如果切换到poetry会破坏兼容性导致项目只能用poetry开发。

