---
category: 随笔
date: 2018-11-26 03:31:50.455102
description: ''
image: https://cdn.wccftech.com/wp-content/uploads/2018/02/Twitter.jpeg
tags:
- 感悟
template: post
title: 第一次成为网红
---

最近发生了两件事情。

第一件，我正式成功[Pipenv](https://github.com/pypa/pipenv)的官方维护者之一。2018我才开始涉足开源，Github上截止现在有394个commit，也算是对我这些贡献的一个回报吧。还是有点小满足了虚荣心的。

第二件，我在推特上发了一个关于Python 3 f-string vs format vs %的性能比较。这是两天内推文的动态：

![](//static.frostming.com/images/2018-11-twitter.jpg)

我有点惊呆了，因为我在微博上从来没有到达过这个热度，而这个推特账号是今年才建立的。其实还是要归功于我在Pipenv上的活跃，得以结识了一些大V，Python核心开发之一[Nick Coghlan](https://twitter.com/ncoghlan_dev)就关注了我，并且转发了这条推特。虽然马上就被另一个核心开发指出了我的错误：
<blockquote class="twitter-tweet" data-lang="zh-cn"><p lang="en" dir="ltr">Try my perf module, python3 -m perf timeit --duplicate=1024 -s &#39;a=1; b=2&#39; ...<br>* &#39;&quot;%s + %s = %s&quot; % (a, b, a + b)&#39;: 254 ns +- 10 ns<br>* &#39;&quot;%d + %d = %d&quot; % (a, b, a + b)&#39;: 268 ns +- 13 ns<br>* &#39;f&quot;{a} + {b} = {a+b}&quot;&#39;: 273 ns +- 6 ns<br>* &#39;&quot;{} + {} = {}&quot;.format(a, b, a+b)&#39;: 321 ns +- 10 ns</p>&mdash; Victor Stinner 🐍 (@VictorStinner) <a href="https://twitter.com/VictorStinner/status/1065626845541003264?ref_src=twsrc%5Etfw">2018年11月22日</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>
我本来就是随便发一个我的新发现，没想到影响挺大，为防止误导更多的人，我已经删除了原推。