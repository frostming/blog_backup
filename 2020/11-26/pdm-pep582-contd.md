---
author: Frost Ming
category: 编程
date: 2020-11-26 03:04:20.729759
description: 无限接近node.js的本地包体验
image: https://static.frostming.com/images/2020-04-pep582.png
tags:
- Python
- Packaging
title: PEP 582 的开发日志(续)
---

这篇文章是[PEP 582的开发日志](https://frostming.com/2020/04-12/pdm-pep582)的后续，因为按照之前的实现方法，有几个缺陷：

1. 为了可执行文件能直接全局运行，需要在文件里塞私货
2. 需要魔改`lib`目录下的`site.py`，可能造成冲突

但是，非常Exciting地，现在PDM的PEP 582可以说是完全态了！先看下Demo：

<!--more-->

![](https://static.frostming.com/images/pdm-gif.gif)

依赖被安装在了隔离的目录`__pypackages__`，但运行却可以通过全局解释器`python`运行。

- 没有`activate`，改任何shell变量
- 没有用一个包装过的`python`可执行文件
- 没有`pdm run`前缀

为了证明依赖确实没有被安装在全局解释器下，我演示了在别的目录`import flask`返回失败。简而言之，就是**用全局的解释器，加载隔离的依赖目录**，无限接近Node.js的体验。你所要做的，只是`export PYTHONPEP582=1`，但其实这也是一个feature开关，未来可能不再需要。

## 这是怎么做到的

难道我魔改了Python解释器？不不不，秘诀还是在Python的`site`模块中。前文提到过，`site`模块有个最大的特点，就是**除非你显式加上`-S`参数，它会在Python启动时作为模块执行**，这就为一些稀奇古怪的startup钩子提供了可能[^1]。`site`模块的执行流程大概是这样的：

![image-20201126104508094](https://static.frostming.com/images/image-20201126104508094.png)

要在这里加私货，有4个途径：

1. 魔改一个`site.py`使得`python -m site`的时候执行到这里（可能导致和其他同样魔改这个文件的工具冲突，不取）
2. 写一个`sitecustomize.py`（可能导致和其他同样写这个文件的工具冲突，不取）
3. 写一个`usercustomize.py`（同2）
4. 写一个`.pth`文件，使用`import`开头的行，达成执行其中代码的效果（可取）

所以最后就采取了方法4，写了一个`_pdm_pep582.pth`，内容很简单：

```python
import _pdm_pep582;_pdm_pep582.init()
```

这个`init()`函数主要做的就是从`sys.path`中去除`site-packages`，然后加上`__pypackages__`（如果没有找到`__pypackages__`则不做任何事。最后这两个文件都会被塞到`site-packages`下面，当然这些过程在使用PDM时会自动帮你完成，用户完全无感知。但我之所以说无限接近node，因为毕竟Python解释器不止一个，就算去除所有的虚拟环境，也有几个版本并行存在。而这个机制要生效，必须要让PDM往里塞过私货才行。

[^1]: 你们可能知道`PYTHONSTARTUP`也可以控制启动的行为，但这也需要额外配置，故不考虑

## 一些感想

其实这次改进要感谢Poetry discord里面的一个提问

![image-20201126105751011](https://static.frostming.com/images/image-20201126105751011.png)

我一直都知道`.pth`的用法，但没有去想到可以用它来魔改Python解释器，只是微小的一步。有些时候要对已经实现的代码时常审视，说不定就找到了新的途径。

以上。