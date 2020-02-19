---
author: null
category: 编程
date: 2016-08-23 15:13:23
description: null
image: null
tags:
- Python
- Python3
title: 如何编写向前兼容的 Python 代码
---

<a href="https://juejin.im/entry/592553dfda2f60005d7be514/detail"><img src="https://badge.juejin.im/entry/592553dfda2f60005d7be514/likes.svg?style=flat"/></a>

> 本文翻译自 [Armin Ronacher](http://lucumr.pocoo.org/about/) 的文章 [Writing Forwards Compatible Python Code](http://lucumr.pocoo.org/2011/1/22/forwards-compatible-python/)

对于网络应用来说，目前最安全的做法是仍然坚持使用 Python 2.x，即使是新的项目。一个简单的原因是现在 Python 3 还不支持足够多的库，而将已有的库移植到 Python 3 上是一个巨大的工作。当所有人都在抱怨升级到 Python 3 是如此艰难和痛苦的时候，我们如何才能让这件事变得容易一点呢？

对于一个顶层应用来说，如果它的依赖库移植后行为一致，把它升级到 Python 3 就不难了。其实升级到 Python 3 从来都不应该是一件痛苦的事。因此，本文尝试列举一些编写新的代码时应该和不应该做的事。
<!--more-->

## 以 2.6 为基准

如果你要编写一个新项目，就从 Python 2.6 或 2.7 开始，它们有许多升级到 Python 3 的便利。如果你不打算支持旧版本的 Python 你已经可以使用许多 Python 3 中的新特性了，只要在代码中打开就行了。

你应该使用的一些 `__future__` 中的特性：

- `division` 我必须承认我非常讨厌 Python 2 中的 future division。当我审核代码时我需要不停地跳到文件开头来检查用的是哪种除法机制。然而这是 Python 3 中的默认除法机制，所以你需要使用它。
- `absolute_import` 最重要的特性。当你在 foo 包内部时，`from xml import bar` 不再导入一个 `foo.xml` 的模块，你需要改为 `from .xml import bar`。更加清晰明了，帮助很大。

至于函数形式的 `print` 导入，为了代码清晰，我不建议使用它。因为所有的编辑器会将`print` 作为关键字高亮，这此让人产生困惑。如果一件事情在不同的文件里表现不一致我们最好尽可能避免它。好在用 2to3 工具可以很方便地转换，所以我们完全没必要从 future 中导入它。

最好不要从 future 中导入 `unicode_literals`，尽管它看上去很吸引人。原因很简单，许多 API 在不同地方支持的字符串类型是不同的，`unicode_literals` 会产生反作用。诚然，这个导入在某些情况下很有用，但它更多地受制于底层的接口（库），且由于它是 Python 2.6 的特性，有许多库支持这个导入。不需要导入 `unicode_literals` 你就能使用 `b'foo'` 这样的写法，两种方法都是可用的并且对 2to3 工具很有帮助。

## 文件输入输出与 Unicode

文件的输入输出在 Python 3 中改变很大。你终于不用在为新项目开发 API 时费尽心力处理文件 unicode 编码的问题了。

当你处理文本数据时，使用 [codecs.open](http://docs.python.org/library/codecs.html) 来打开文件。默认使用 utf-8 编码除非显式地定义或者只对 unicode 字符串操作。若你决定使用二进制输入输出，打开文件时记得用 `'rb'` 而不是 `'r'` 标志。这对于适当的 Windows 支持来说是必要的。

当你处理字节型数据时，使用 `b'foo'` 将字符串标为字节型，这样 2to3 就不会将它转换为 unicode。注意以下 Python 2.6：
```python
>>> b'foo'
'foo'
>>> b'foo'[0]
'f'
>>> b'foo' + u'bar'
u'foobar'
>>> list(b'foo')
['f', 'o', 'o']
```
与 Python 3 对待字节型字符串的区别：
```python
>>> b'foo'[0]
102
>>> b'foo' + 'bar'
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: can't concat bytes to str
>>> list(b'foo')
[102, 111, 111]
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: can't concat bytes to str
```
为了达成与 Python 2.6 同样的效果，你可以这样做：
```python
>>> b'foo'[0:0 + 1]
b'f'
>>> b'foo' + 'bar'.encode('latin1')
b'foobar'
>>> to_charlist = lambda x: [x[c:c + 1] for c in range(len(x))]
>>> to_charlist(b'foo')
[b'f', b'o', b'o']
```
此代码在 2.6 和 3.x 上均能正常工作。

## 安全好过道歉

在很多事情上 2to3 并不能达到预期效果。一部分是 2to3 可能有 BUG 的地方，另外的则是因为 2to3 不能很好的预测你的代码的目的。

### str 相关的递归错误

在 Python 2 中很多人像下面这样写代码：
```python
class Foo(object):
    def __str__(self):
        return unicode(self).encode('utf-8')
    def __unicode__(self):
        return u'Hello World'
```
2to3 预设你的 API 不兼容 unicode ，会将它转换成下面这样：
```python
class Foo(object):
    def __str__(self):
        return str(self).encode('utf-8')
    def __unicode__(self):
        return 'Hello World'
```
这就有错误了。首先 `__unicode__` 不能在 Python 3 中使用，其次当你对 `Foo` 的一个实例调用 `str()` 方法时，`__str__` 将调用自身而由于无限递归触发一个 RuntimeError。这个错误可以通过自定义 2to3 修改器解决，也可以写一个简单的辅助类来检查是否是 Python 3：
```py
import sys

class UnicodeMixin(object):
    if sys.version_info > (3, 0):
        __str__ = lambda x: x.__unicode__()
    else:
        __str__ = lambda x: unicode(x).encode('utf-8')

class Foo(UnicodeMixin):
    def __unicode__(self):
        return u'Hello World'
```
用这种方法你的对象在 Python 3 中仍然有一个 `__unicode__` 属性，但却不会有任何损害。当你想去掉 Python 2 支持时你只需遍历 `UnicodeMixin` 的所有派生类，将 `__unicode__` 重命名为 `__str__`，然后再删掉辅助类。

### 字符串比较

这个问题会稍微棘手一点，在 Python 2 中下面这段代码是正确的：
```py
>>> 'foo' == u'foo'
True
```
在 Python 3 中却并非如此：
```py
>>> b'foo' == 'foo'
False
```
更糟糕的是 Python 2 不会抛出一个比较的警告（即使打开了 Python-3-warnings），Python 3 也不会。那么你如何找到问题所在呢？我写了一个名为 [unicode-nazi](http://pypi.python.org/pypi/unicode-nazi) 的小型辅助模块。只要导入该模块，当你试图同时操作 unicode 和 bytes 型字符串时会自动抛出警告：
```py
>>> import unicodenazi
>>> u'foo' == 'foo'
__main__:1: UnicodeWarning: Implicit conversion of str to unicode
True
```

## 字符串是什么？

下面这张表列举了一些字节型字符串，和它们在 Python 3 中将变成什么：

| 类型         | Python 3 中的类型（unicode == str） |
| ------------ | ----------------------------------- |
| 标识         | unicode                             |
| 文档字符串   | unicode                             |
| `__repr__`   | unicode                             |
| 字典的字符键 | unicode                             |
| WSGI 的环境变量键 | unicode                        |
| HTTP 的 header值，WSGI 的 环境变量值  | unicode，在 3.1 中仅限于 ASCII，在 3.2 中仅限于 latin1 |
| URL          | unicode，部分 API 也接受字节。需要特别注意的是，为了使用所有标准库函数，URL 需要编码为 utf-8 |
| 文件名       | unicode 或者字节，大部分 API 接受两者但不支持隐式转换。 |
| 二进制内容 | 字节或字节序列。注意第二种类型是可变的，所以你要清醒认识到你的字符串对象是可变的。 |
| Python 代码 | unicode，在交给 exec 执行前你需要自行解码。 |

## Latin1 很特别

在某些地方（比如 WSGI）unicode 字符串必须是 latin1 的子集。这是因为 HTTP 协议并未指定编码方式，为了保证安全，假定为使用 latin1 。假如你要同时控制通信的两端（比如 cookies）你当然可以使用 utf-8 编码。那么问题来了：如果请求头只能是 latin1 编码时是怎么工作的呢？在且仅在 Python 3 中你需要用一些小伎俩：
```py
return cookie_value.encode('utf-8').decode('latin1')
```
你只是反 unicode 字符串伪编码为 utf-8。WSGI 层会将它重新编码为 latin1 并将这个错误的 utf-8 字符串传输出去，你只要在接收端也做一个反向的变换就可以了。

这虽然很丑陋，但这就是 utf-8 在请求头中的工作方式，而且也只有 cookie 头受此影响，反正 cookie 头也不是很可靠。

在 WSGI 还剩下的问题就只有 PATH_INFO / SCRIPT_NAME 元组了，你的框架运行在 Python 3 时应该解决这个问题。
