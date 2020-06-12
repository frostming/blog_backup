---
author: Frost Ming
category: 随笔
date: 2020-06-11 07:06:26.773597
description: Frost为何变自闭
image: //static.frostming.com/images/image-20200611143616626.png
tags:
- Python
title: Meetup首秀，Live coding翻车
---

由于疫情的关系，今年的Python Meetup得以在线上举行，我也头一回报名了演讲。

* 视频录像：https://www.bilibili.com/video/BV1KT4y1J7PU
* Slides地址：https://slides.fming.dev/pep582
* Live coding仓库地址：https://github.com/frostming/package-manager-demo

现在开始简单的复盘发生了什么。

我一开始就敲定了本次演讲的主题是PEP 582，然后附带展示下我今年做的项目[pdm](https://github.com/frostming/pdm)。但转念一想，感觉这个PEP的内容不够撑起一次演讲，我也想摆脱一下Explain and show的演讲模式，于是就**不自量力**地选择准备一场Live Coding。现在看来这个选择不太明智：

* 其实完整地演示PDM需要花费很多时间，特别是我还有很多重要的特性没有在演讲中演示（全局包管理、插件系统）。我在这里耗时估计太乐观了。
* Live Coding选择的主题略显复杂，涉及到三个数据模型的相互作用和一些Python打包的机制，需要费时间解释这些东西。
* Live Coding本身的不可控因素太多了，事先只演练了三次，实际演示时任何微小的错误都有可能犯，而依赖解析造成了Debug的成本比较大。
* [Tsu-ping](https://github.com/uranusjr)竟然偷偷阻击我，我要是知道他要来我肯定不干Live Coding的事>_<

但不管怎么样我还是干了，干了还是翻车了，翻车以后我还是自闭了，自闭归自闭我还是来复盘了。就这样吧。

* * *

好了如果大家围观完我的窘迫以后，想知道问题出在哪了导致我没有成功？答案就在import语句之后的第一行代码：
```python
PYTHON_VERSION = platform.version()
```
这一句希望返回Python的版本号，但实际返回了当前系统的版本！正确的应该是：
```python
PYTHON_VERSION = platform.python_version()
```