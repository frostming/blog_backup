---
author: Frost Ming
category: 编程
date: 2020-03-21 08:25:22.807951
description: ''
image: //static.frostming.com/images/2020-03-pyenv.png
tags:
- Python
- 小技巧
title: Pyenv 安装本地加速方法
---

Pyenv 经常被用来管理多个Python版本，但由于众所周知的原因，用Pyenv安装Python时下载速度总是不尽如人意。下面提供一个使用本地安装包加速下载过程的步骤。
<!--more-->

**首先**，到官网 https://www.python.org/downloads/ 下载对应版本的tar.xz安装包，这里以[3.8.2版本](https://www.python.org/ftp/python/3.8.2/Python-3.8.2.tar.xz)为例，假如下载到了`~/workspace/downloads/`下面。

**第二步**，在`~/workspace/downloads/`目录中打开终端，启动一个静态文件服务器：
```bash
$ python3 -m http.server 8000
```
端口号不一定要是8000，选择一个未被占用的即可。

**第三步**，启动另外一个终端窗口，将安装的源指向本地的这个服务器，然后安装Python:

```bash
$ export PYTHON_BUILD_MIRROR_URL="http://localhost:8000"
$ pyenv install 3.8.2
python-build: use openssl@1.1 from homebrew
python-build: use readline from homebrew
Downloading Python-3.8.2.tar.xz...
-> https://www.python.org/ftp/python/3.8.2/Python-3.8.2.tar.xz
```
这一步会卡住，没关系，看到`Downloading Python`出现以后，使用<kbd>Ctrl</kbd> + <kbd>C</kbd> 强制停止。

**第四步**，回到文件服务器的那个窗口，查看日志：

```bash
$ python3 -m http.server 8000
Serving HTTP on :: port 8000 (http://[::]:8000/) ...
::ffff:127.0.0.1 - - [21/Mar/2020 16:18:11] code 404, message File not found
::ffff:127.0.0.1 - - [21/Mar/2020 16:18:11] "HEAD /2646e7dc233362f59714c6193017bb2d6f7b38d6ab4a0cb5fbac5c36c4d845df HTTP/1.1" 404 -
```
你会看到一个404的请求，请求的URL是`2646e7dc233362f59714c6193017bb2d6f7b38d6ab4a0cb5fbac5c36c4d845df`，把它复制下来。

**第五步**， 将下载好的tar.xz的文件名改成上一步复制的值`2646e7dc233362f59714c6193017bb2d6f7b38d6ab4a0cb5fbac5c36c4d845df`，然后在另一个终端窗口中重新安装，你就会发现下载速度非常快了。