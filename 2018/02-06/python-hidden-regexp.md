---
category: 编程
date: 2018-02-06 09:08:14.770294
description: Python's Hidden Regular Expression Gems
image: null
tags:
- Python
- 正则表达式
- 翻译
template: post
title: '[译]Python正则表达式拾珠'
---

> 原文作者：Armin Ronacher<br>
> 原文链接：http://lucumr.pocoo.org/2015/11/18/pythons-hidden-re-gems/

Python标准库中有很多非常恶心的模块，但Python的`re`模块不是其中之一。虽然它已经很老了而且多年未更新，它仍是我认为的众多动态语言中最好的（正则表达式模块）。

对这个模块，我经常能发现有趣的东西。Python是少有的几个，本身没有集成正则表达式的动态语言之一。虽然缺少解释器的语法支持，但从纯粹的API角度来说，它弥补了核心系统设计的缺憾。而同时它又非常奇特。比如它的解析器是用纯Python实现的，你如果去追踪它的导入过程，会发现一些奇怪的事：它把90%的时间都花在一个`re`的支持模块上了。

## 久经考验

Python的正则表达式模块很早就存在标准库之中了。先不说Python 3，从它有的那天起，除了中途加入了unicode的基础支持，就基本没变过了。直到今天（译注：本文作于2015.11.8），它的成员枚举还是错的（对一个正则表达式的pattern对象使用`dir()`看看）。

然而，老模块的好处是不同的Python版本都一样，非常可靠。我从未因为正则表达式模块的改动而调整任何东西。对于我这种要写很多正则表达式的人来说，这是个好消息。

它的设计中有个有趣的特点：它的解析器和编译器是用Python写的，而匹配器是用C写的。只要你想，你能跳过正则解析，直接把解析器的内部结构传给编译器。这没有包含在文档中，但这是可行的。

除此之外，正则表达式系统中还有很多东西未见于文档或文档不足。所以我希望给大家举例说明为什么Python的正则表达式模块这么酷。

## 迭代匹配

毫无疑问，Python正则表达式系统的最强特性之一，就是它严格区分匹配和搜索。这在其他正则表达式引擎中并不多见。具体来说，你在进行匹配时能提供一个索引值作为偏移量，匹配将基于该位置进行。

具体地，这意味着你能做类似下面的事情：
```python
>>> pattern = re.compile('bar')
>>> string = 'foobar'
>>> pattern.match(string) is None
True
>>> pattern.match(string, 3)
<_sre.SRE_Match object at 0x103c9a510>
```

这极大地有助于实现一个语法分析器，因为你能继续使用`^`来标明字符串的起始位置，只需要增加索引值就可以进行后续的匹配。这也意味着我们不需要自己对字符串进行切片，节省了大量内存开销和字符串拷贝操作（Python对此并不是特别在行）。

除了匹配之外，Python还能进行搜索，它会一直向后寻找直到找到匹配字符串：
```python
>>> pattern = re.compile('bar')
>>> pattern.search('foobar')
<_sre.SRE_Match object at 0x103c9a578>
>>> _.start()
3
```

## 不匹配也是一种匹配

一个常见的问题是，如果没有匹配的字符串，会对Python造成很大的负担。思考下实现一个类似百科语言的分词器（比如说markdown）。在表示格式的标识符之间，有很长的文字也需要处理。所以匹配标识符之间时，一直在寻找是否有别的标识符也需要处理。如何跳过这一过程呢？

一种方法是编译一些正则表达式，放在一个列表中，再逐一检查。如果一个都不匹配则跳过一个字符：
```python
rules = [
    ('bold', re.compile(r'\*\*')),
    ('link', re.compile(r'\[\[(.*?)\]\]')),
]

def tokenize(string):
    pos = 0
    last_end = 0
    while 1:
        if pos >= len(string):
            break
        for tok, rule in rules:
            match = rule.match(string, pos)
            if match is not None:
                start, end = match.span()
                if start > last_end:
                    yield 'text', string[last_end:start]
                yield tok, match.group()
                last_end = pos = match.end()
                break
        else:
            pos += 1
    if last_end < len(string):
        yield 'text', string[last_end:]
```

这不是一个优雅的解决方案，也不是很快速。不匹配的字符串越多，过程就越慢，因为每次只前进一个字符，这个循环是在Python解释器里的，处理过程也相当不灵活。对每个标识符我们只得到了匹配的字符串，如果需要加入分组就要进行一点扩展。

有没有更好的方法呢？有没有可能我们能告诉正则表达式引擎，我希望它只扫描若干正则式中的任意一个？

事情开始变得有趣了，这就是我们用子模式`(a|b)`时本质上在做的事。引擎会搜索`a`和`b`其中之一。这样我们就能用已有的正则表达式构造一个巨大的表达式，然后再用它去匹配。这样不好的地方在于所有分组都加入进来以后非常容易把人搞晕。

## 初探Scanner

有意思的来了，在过去的15年中，正则表达式中一直存在一个没有文档的功能：Scanner。scanner是内置的SRE模式对象的一个属性，引擎通过扫描器，在找到一个匹配后继续找下一个。甚至还有一个`re.Scanner`类（也没有文档），它基于SRE模式scanner构造，提供了一些更高一层的接口。

`re`模块中的scanner对于提升「不匹配」的速度并没有多少帮助，但阅读它的源码能告诉我们它是如何实现的：基于SRE的基础类型。

它的工作方式是接受一个正则表达式的列表和一个回调元组。对于每个匹配调用回调函数然后以此构造一个结果列表。具体实现上，它手动创建了SRE的模式和子模式对象（大概地说，它构造了一个更大的正则表达式，且不需要解析它）。有了这个知识，我们就能进行以下扩展：
```python
from sre_parse import Pattern, SubPattern, parse
from sre_compile import compile as sre_compile
from sre_constants import BRANCH, SUBPATTERN


class Scanner(object):

    def __init__(self, rules, flags=0):
        pattern = Pattern()
        pattern.flags = flags
        pattern.groups = len(rules) + 1

        self.rules = [name for name, _ in rules]
        self._scanner = sre_compile(SubPattern(pattern, [
            (BRANCH, (None, [SubPattern(pattern, [
                (SUBPATTERN, (group, parse(regex, flags, pattern))),
            ]) for group, (_, regex) in enumerate(rules, 1)]))
        ])).scanner

    def scan(self, string, skip=False):
        sc = self._scanner(string)

        match = None
        for match in iter(sc.search if skip else sc.match, None):
            yield self.rules[match.lastindex - 1], match

        if not skip and not match or match.end() < len(string):
            raise EOFError(match.end())
```
如何使用呢？像下面这样：
```python
scanner = Scanner([
    ('whitespace', r'\s+'),
    ('plus', r'\+'),
    ('minus', r'\-'),
    ('mult', r'\*'),
    ('div', r'/'),
    ('num', r'\d+'),
    ('paren_open', r'\('),
    ('paren_close', r'\)'),
])

for token, match in scanner.scan('(1 + 2) * 3'):
    print (token, match.group())
```

在上面的代码中，当不能解析一段字符时，将会抛出`EOFError`，但如果你加入`skip=True`，则不能解析的部分将会被跳过，这对于实现像百科解析器的东西来说非常完美。

## 扫描空位

我们在跳过时可以使用`match.start()`和`match.end()`来查看哪一部分被跳过了。所以第一个例子可以改为如下：
```python
scanner = Scanner([
    ('bold', r'\*\*'),
    ('link', r'\[\[(.*?)\]\]'),
])

def tokenize(string):
    pos = 0
    for rule, match in self.scan(string, skip=True):
        hole = string[pos:match.start()]
        if hole:
            yield 'text', hole
        yield rule, match.group()
        pos = match.end()
    hole = string[pos:]
    if hole:
        yield 'text', hole
```

## 解决分组问题

还有一个很烦人的问题：分组的序号不是基于原来的正则表达式而是基于组合之后的。这会导致如果你有一个`(a|b)`的规则，用序号来引用这个分组会得到错误的结果。我们需要一些额外的工作，在SRE的匹配对象上包装一个类，改变它的序号和分组名。如果你对这个感兴趣我已经在一个[github仓库](https://github.com/mitsuhiko/python-regex-scanner)中基于以上方案实现了一个更加复杂的版本，包括了一个匹配包装类和一些例子来告诉你怎么用。