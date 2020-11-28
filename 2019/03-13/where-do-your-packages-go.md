---
category: 编程
date: 2019-03-13 09:53:19.910361
description: 终结一切找不到包、可执行文件的问题
image: //static.frostming.com/images/2019-03-john-westrock-638048-unsplash.jpg
tags:
- Python
- Packaging
template: post
title: 你的 Python 包都装到哪了？
---

## 前言
写这篇文章是因为最近在Python社区看到，有几个求助频率非常高的问题：

* 我安装了pip为什么运行报找不到可执行文件？
* import module为什么报`ModuleNotFound`?
* 为什么我用Pycharm能运行在cmd里运行不了？

授人以鱼不如授人以渔，要解决这类问题，你得知道Python是如何找包的。希望看完这篇文章，能有所帮助。（主要还是下次再有人问，我就可以链接甩脸了哈哈）

## Python是如何寻找包的

现在大家的电脑上很可能不只有一个Python，还有更多的虚拟环境，导致安装包的时候，一不小心你就忘记注意安装包的路径了。首先我们来解决找包的问题，这个问题回答起来很简单，但很多人不知道这个原理。假如你的Python解释器的路径是`<path_prefix>/bin/python`，那么你启动Python交互环境或者用这个解释器运行脚本时，会默认寻找以下位置[^1]：

1. `<path_prefix>/lib`（标准库路径）
2. `<path_prefix>/lib/pythonX.Y/site-packages`（三方库路径，X.Y是对应Python的主次版本号，如3.7, 2.6）
3. 当前工作目录（`pwd`命令的返回结果）

这里如果你用的是Linux上的默认Python，`<path_prefix>`就是`/usr`，如果你是自己使用默认选项编译的，`<path_prefix>`就是`/usr/local`。从上面第二条可以看到不同次版本号的Python的三方库路径不同，如果你把Python从3.6升级到3.7那么之前装的三方库都没法用了。当然你可以整个文件夹都拷贝过去，大部分情况不会出问题。

[^1]: 本文示例均使用Unix路径习惯，如果是Windows系统则应当做适当改动，如`<path_prefix>/bin`应为`<path_prefix>/Scripts`

### 几个有用的函数
* `sys.executable` 当前使用的Python解释器路径
* `sys.path` 当前包的搜索路径列表
* `sys.prefix` 当前使用的`<path_prefix>`

**例：**
```python
>>> import sys
>>> sys.executable
'/home/frostming/.pyenv/versions/3.7.2/bin/python'
>>> sys.path
['', '/home/frostming/.pyenv/versions/3.7.2/lib/python37.zip', '/home/frostming/.pyenv/versions/3.7.2/lib/python3.7', '/home/frostming/.pyenv/versions/3.7.2/lib/python3.7/lib-dynload', '/home/frostming/.local/lib/python3.7/site-packages', '/mnt/d/Workspace/pipenv', '/home/frostming/.pyenv/versions/3.7.2/lib/python3.7/site-packages']
>>> sys.prefix
'/home/frostming/.pyenv/versions/3.7.2'
```

### 使用环境变量添加搜索路径

如果你的包的路径不存在上面列出的搜索路径列表里，可以把路径加到`PYTHONPATH`环境变量里，多个路径用`:`隔开（Windows用`;`）。

但需注意，避免把不同Python版本包的路径加到PYTHONPATH里，比如`PYTHONPATH=/home/frostming/.local/lib/python2.7/site-packages`，因为`PYTHONPATH`中的路径是优先于默认搜索路径，如果用Python 3的话会有兼容性问题。

顺便说下`PATH`是用来找**可执行程序**的搜索路径，假如你在终端中运行命令`my_cmd`，系统会依次扫描`PATH`中的路径，看`my_cmd`是否存在于该路径下，所以如果提示找不到程序或命令无法识别，那你就要看路径是否加到`PATH`里了。

## Python是如何安装包的

现在用安装Python包基本是用的`pip`，就算你是用`pipenv`，`poetry`，底层依然是pip，一律适用。
如果你没有安装`pip`请参考[这里](https://pip.pypa.io/en/stable/installing/)，如果安装了还无法用`pip`命令请参考上一节。

运行`pip`有两种方式：
* `pip ...`
* `python -m pip ...`

第一种方式和第二种方式大同小异，区别是第一种方式使用的Python解释器是写在`pip`里的，一般情况下，如果你的`pip`路径是`<path_prefix>/bin/pip`，那么Python路径对应的就是`<path_prefix>/bin/python`。第二种方式则显式地指定了Python的位置。这条规则，对于所有Python的可执行程序都是适用的。流程如下图所示。
![](//static.frostming.com/images/2019-03-pip-flow2.png)

那么，不加任何自定义配置时，使用`pip`安装包就会自动安装到`<path_prefix>/lib/pythonX.Y/site-packages`下（`<path_prefix>`是从上一段里得到的），可执行程序安装到`<path_prefix>/bin`下，如果需要在命令行直接使用`my_cmd`运行，记得加到`PATH`。

### pip中更改安装位置的选项

* `--prefix PATH`，替换`<path_prefix>`为给定的值
* `--root ROOT_PATH`，在`<path_prefix>`前面加上`ROOT_PATH`，比如`--root /home/frostming`，`<path_prefix>`就会从`/usr`变成`/home/frostming/usr`
* `--target TARGET`，直接指定安装位置到`TARGET`

## 虚拟环境

虚拟环境就是为了隔离不同项目的依赖包，使他们安装到不同的路径下，以防止依赖冲突的问题。理解了Python是如何安装包的机制之后就不难理解虚拟环境（`virtualenv`, `venv`模块）的原理。其实，运行`virtualenv myenv`会复制一个新的Python解释器到`myenv/bin`下，并创建好`myenv/lib`，`myenv/lib/pythonX.Y/site-packages`等目录（`venv`模块不是用的复制，但结果基本一样）。执行`source myenv/bin/activate`以后会把`myenv/bin`塞到`PATH`前面，让这个复制出来的Python解释器最优先被搜索到。这样，后续安装包时，`<path_prefix>`就会是`myenv`了，从而实现了安装路径的隔离。

## 总结

看到这里大家可以发现，关于包路径搜索最重要的就是这个`<path_prefix>`路径前缀，而这个值又是从使用的Python解释器路径推导出来的。所以要找到包的路径，只需要知道解释器的路径就可以了，如果遇到改变包的路径，只需要通过正确的`PATH`设置，指定你想要的Python解释器即可。

现在回到开头的三个问题，大家会解决了吗？在评论区写出你的排查步骤或解决方法。
