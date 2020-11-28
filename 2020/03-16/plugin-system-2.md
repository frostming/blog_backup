---
category: 编程
date: 2020-03-16 06:56:48.402167
description: 安装即生效的插件
image: https://images.unsplash.com/photo-1508920291026-c344bbfca1ab?ixlib=rb-1.2.1&auto=format&fit=crop&w=1350&q=80
tags:
- Python
- Flask
template: post
title: 浅谈 Python 库的插件系统设计
---

[上一篇文章](https://frostming.com/2020/03-16/plugin-system-1)介绍了可选配型插件的实现的例子，这篇文章继续说说安装即生效的插件原理。

<!--more-->

## 安装即生效的插件

如果使用方只用把插件加到依赖里，安装以后这个插件就自动生效了，那使用方岂不是非常方便？但Python是个运行时的动态语言，所有代码需要生效都要实际执行它，那么这个执行时谁来做，什么时机执行呢？

### 插件宿主加载并执行

第一种方法最为自然，宿主预留出加载插件的地方，执行到这个地方，就把**当前所有安装的插件**载入，并调用执行。那么关键就是如何寻找当前所有安装的插件了，Python包提供了这样的机制，叫做`entry point`。简单来说，就是Python的库打包时，像包信息中注册写入一个配置，把某个Python对象注册为特定类型（类型需要与宿主约定好）的载入点，宿主则可以通过`pkg_resources.iter_entry_points(ep_type)`扫描所有这些载入点，把注册好的对象导入进来。插件起作用的方法，既可以调用这个对象的某个函数，也可以在插件顶层代码中实现，因为导入插件会执行一次`import`，所有的顶层代码都会执行一次。

如果大家写过命令行程序，就知道定义命令行入口的方法：
```python
# setup.py

setup(
    ...
    entry_points={
        "console_scripts": ["mycli = mypackage.cli:main"]
    }
    ...
)
```
这里的`console_scripts`其实就是最常用的一种载入点类型，包安装器会找到这个载入点将对应的命令行入口对象生成为一个命令行脚本。

### 利用Python的启动机制执行

但如果这个宿主没有为插件预留入口，或者它没有设计成可扩展的，那我们也有办法<del>硬插进去</del>。原理就在Python的`site`模块中，看看它的[官方文档](https://docs.python.org/3/library/site.html)：

>A path configuration file(.pth) is a file whose name has the form name.pth and exists in one of the four directories mentioned above; its contents are additional items (one per line) to be added to sys.path. Non-existing items are never added to sys.path, and no check is made that the item refers to a directory rather than a file. No item is added to sys.path more than once. Blank lines and lines beginning with # are skipped. **Lines starting with import (followed by space or tab) are executed.**

看到最后一句话了吗，你只要在一个`.pth`结尾的文件中写上一句**以import开头**的语句，并将这个文件随包发布[^1]，那么这行语句就会在Python启动时自动执行。基于Python的动态特性，你几乎能在运行时修改任何东西，所以这行语句能做什么就大有发挥的空间了。当然，这种没有被宿主允许的走后门行为，还是不如第一种方法好。

[^1]: 这个文件必须安装在顶层目录，和包同级，即放在`site-packages`目录下。


## 使用安装即生效插件的项目

### Flask CLI

相比于上一篇文章写的Flask扩展方法，可能更少的人知道Flask还可以安装即生效的方法，安装额外的命令。实现的方法就是前文提到的插件宿主加载并执行方法。扩展的`setup.py`写法为：

```python
# setup.py

setup(
    ...
    entry_points={
        "flask.command": ["foo = mypackage.cli:main"]
    }
    ...
)
```

安装完这个包以后，你就可以用`flask foo`这条命令了。

### Pytest

Pytest也有海量的插件可用，它是基于`pluggy`框架构建的插件系统，除了那些顶层可用的函数、fixtures，pytest还预定义了很多钩子，在插件中可以实现这些钩子函数达到修改pytest的效果：

- `pytest_addoption(parser` 添加命令行选项
- `pytest_collection_modifyitems(config, items)`  修改收集到的测试用例列表
- `pytest_configure(config)` 读取配置项
- `pytest_cmdline_main(config)` 修改主函数逻辑
- ...

Pytest使用的entry_points类型叫做`pytest11`

### PDM

在做PDM的插件系统的时候，我也借鉴了这些项目的经验。首先必须留出插件载入点，通过entry_points的方式载入插件，其次我希望暴露的对象尽可能少，插件的入口尽可能少。
这样就要求PDM中的基本对象类型，都是可以继承然后替换的。所以我做了一个主入口对象，用来承载所有这些信息，插件作者只要读入这个对象，就可以做出想要的修改了，核心代码如下：

```python
class Core:
    """A high level object that manages all classes and configurations
    """

    def __init__(self):
        self.version = __version__

        self.project_class = Project
        self.repository_class = PyPIRepository
        self.resolver_class = Resolver
        self.synchronizer_class = Synchronizer

        self.parser = None
        self.subparsers = None
    
    def register_command(
        self, command: Type[BaseCommand], name: Optional[str] = None
    ) -> None:
        """Register a subcommand to the subparsers,
        with an optional name of the subcommand.
        """
        command.project_class = self.project_class
        command.register_to(self.subparsers, name)

    @staticmethod
    def add_config(name: str, config_item: ConfigItem) -> None:
        """Add a config item to the configuration class"""
        Config.add_config(name, config_item)

    def load_plugins(self):
        """Import and load plugins under `pdm.plugin` namespace
        A plugin is a callable that accepts the core object as the only argument.

        :Example:

        def my_plugin(core: pdm.core.Core) -> None:
            ...

        """
        for plugin in pkg_resources.iter_entry_points("pdm.plugin"):
            plugin.load()(self)
```
两个函数，`register_command()` 可以添加、修改子命令，`add_config()` 可以添加、修改配置项，`load_plugins()` 用来载入所有entry_ponts并执行，执行时会把主入口对象当做参数传给插件对象。entry_point的名称为`pdm.plugins`。