---
author: Frost Ming
category: 编程
date: 2020-04-12 04:29:14.356700
description: PDM 实现 PEP 582 遇到的坑
image: //static.frostming.com/images/2020-04-pep582.png
tags:
- 日志
- Python
title: PEP 582的开发日志
---

[PEP 582](https://www.python.org/dev/peps/pep-0582/) 是Python的一个隔离项目环境的提案。PDM作为现有的唯一一个具有完备PEP 582支持的包管理器，在实现的过程中也并非一帆风顺。本文将介绍一些关键PEP 582特性的实现方法和历程。
<!--more-->

## 加载项目包目录

这是PEP 582的核心，也是事实上提案唯一阐明的事情，就是项目的包都会安装在`__pypackages__/X.Y/lib`下面。在Python中如何挂载一个额外路径到包搜索路径中呢？再简单不过，就是利用环境变量`PYTHONPATH`。这也是现在所有PEP 582的实现使用的方法，包括:

1. [pythonloc](https://github.com/cs01/pythonloc/blob/a6ed86e3ca91f9ecd80c7bf85d75fd3db5355e88/pythonloc/pythonloc.py#L27-L33)，一个PEP 582的试验项目
2. [pyflow](https://github.com/David-OConnor/pyflow/blob/fe152cc714ed3a6eaf412b2612f6e7ed9951a87e/src/main.rs#L1435-L1441)，一个用Rust做的Python包管理器
3. [pdm的实现](https://github.com/frostming/pdm/blob/5b91a1c635ef188bdfd1ab171e02041e5a26f112/pdm/models/environment.py#L156-L161)

但仅仅做到这里是不够的，在pythonloc的README中提到：

>This PEP first looks to `__pypackages__` but will fall back to looking in site-packages. This is not entirely hermetic and could lead to some confusion around which packages are being used. I would prefer the default search path be only `__pypackages__` and nothing else.

那么如何让Python启动时不要加载site-packages呢？这个特性也是我最近才实现的。乍一看site-packages好像是Python的机制，不好做手脚，但经过一番搜索我发现了Python的内置模块`site`就是[控制这个事情](https://docs.python.org/3/library/site.html)的：

>**This module is automatically imported during initialization**. The automatic import can be suppressed using the interpreter’s `-S` option.
>
>Importing this module will append site-specific paths to the module search path and add a few builtins, unless `-S` was used. In that case, this module can be safely imported with no automatic modifications to the module search path or additions to the builtins. To explicitly trigger the usual site-specific additions, call the `site.main()` function.

我觉得找到了解决方法：在用户`pdm run python`的时候，自动给他添加`-S`参数不就行了？看看效果：

```bash
$ pdm run python -S -c "import sys;print(sys.path)"
[
    '',
    '/Users/fming/wkspace/github/pdm-test/__pypackages__/3.8/lib',
    '/Users/fming/Library/PythonUp/versions/3.8/lib/python38.zip',
    '/Users/fming/Library/PythonUp/versions/3.8/lib/python3.8',
    '/Users/fming/Library/PythonUp/versions/3.8/lib/python3.8/lib-dynload'
]
```
Perfect like a shit! 不是吗？`sys.path`里面有本地的包目录，但没有`site-packages`了。问题解决了吗？没有！先喘口气，看看这个`sys.path`，不知有没人发现问题在哪。

好了不卖关子了，这里面缺少了`.pth`文件[^1]包含的搜索路径。通常`setuptools`在安装可编辑(editable)包的时候会在`__pypackages__/X.Y/lib`下面塞一个`easy-install.pth`文件，用来把可编辑包的真正路径给包含进`sys.path`中来，而这个过程恰好是由`site.py`完成的，现在把它禁掉了就都没了。

[^1]: .pth文件中包含的路径可以被加载到`sys.path`中，参考[官方文档](https://docs.python.org/3/library/site.html)

那么只能走另外的路了，其实除了`easy-install.pth`，`setuptools`还会添加一个`site.py`来完成这个.pth文件的加载。这个文件会在Python启动时执行，那就可以在这里操作`sys.path`去掉site-packages的路径了。具体改动可以看[这个PR](https://github.com/frostming/pdm/pull/104)，改完之后再看看效果：
```bash
$ pdm run python -c "import sys;print(sys.path)"
[
    '',
    '/Users/fming/wkspace/github/pdm-test/__pypackages__/3.8/lib',
    '/Users/fming/wkspace/github/pdm-test',
    '/Users/fming/Library/PythonUp/versions/3.8/lib/python38.zip',
    '/Users/fming/Library/PythonUp/versions/3.8/lib/python3.8',
    '/Users/fming/Library/PythonUp/versions/3.8/lib/python3.8/lib-dynload'
]
```
这其中第二个路径，就是通过`easy-install.pth`加载的路径。

## 执行可执行文件时自动加载项目包目录

除了通过`pdm run`加载项目包目录，我还希望在（外部）直接执行可执行文件时自动加载项目包目录。因为包都是通过PDM安装的，我们自然可以在可执行文件里做修改来达成这个效果。

先简单说下PDM安装包的过程，无论是什么形式的依赖定义，最终都会构造出一个wheel包的格式，再安装这个wheel包。如果你打开`__pypackages__/X.Y/bin`下面的任意一个可执行文件看，会发现它们的内容都是差不多的：
```python
#!/Users/fming/Library/PythonUp/bin/python3
# -*- coding: utf-8 -*-
import re
import sys

from wheel.cli import main
if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw|\.exe)?$', '', sys.argv[0])
    sys.exit(main())
```
第六行是实际的入口，只有这一行会变动，于是我猜测一定是有模板填充。所以我全局搜索特征字符串，果然在`distlib/scripts.py`里面找到了这个模板，它是`ScriptMaker`类的一属性，而`ScriptMaker`刚好是作为`wheel.install()`的参数传进去的。那么解决方法就比较明显了——自己构造`ScriptMaker`实例，然后修改`script_template`属性：
```python
maker.script_template = maker.script_template.replace(
    "import sys",
    "import sys\nsys.path.insert(0, {!r})".format(paths["platlib"]),
)
```
在`import sys`后面直接加了一句，插入包的路径。

问题还没有完全解决，对于可编辑的包，并不是由wheel格式安装的，查看可编辑包的可执行文件，可以发现内容稍有不同：
```python
#!/Users/fming/Library/PythonUp/bin/python3
# EASY-INSTALL-ENTRY-SCRIPT: 'pdm-test','console_scripts','pdm-test'
__requires__ = 'pdm-test'
import re
import sys
from pkg_resources import load_entry_point

if __name__ == '__main__':
    sys.argv[0] = re.sub(r'(-script\.pyw?|\.exe)?$', '', sys.argv[0])
    sys.exit(
        load_entry_point('pdm-test', 'console_scripts', 'pdm-test')()
    )
```
类似的，这个文件内容也是有一个模板，只是在`setuptools`中，解决方法也是一样，就不赘述了。