---
author: Frost Ming
category: 编程
date: 2020-05-12 13:25:40.235082
description: ''
image: ''
tags:
- Python
title: 从 Python 的魔法方法说开去
---

一天我在群里看到这样一个有意思的Python现象：
<!--more-->

```python
>>> import os
>>> r=os.popen('ls')
>>> r.__next__()
'0B4581EB10DBC182A83D85B0024F1E70.jpg\n'
>>> next(r)
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
TypeError: '_wrap_close' object is not an iterator
>>>
```

如果你对Python的魔法方法有所了解，就能发现这里的奇怪之处：`popen`的对象有`__next__()`方法，但却不能被`next()`调用，也就不是个迭代器。还有这种事吗？于是我们来看源码，看看`popen()`到底返回了个什么对象（省略了无关代码）：
```python
def popen(cmd, mode="r", buffering=-1):
    ...
    return _wrap_close(io.TextIOWrapper(proc.stdin), proc)

# Helper for popen() -- a proxy for a file whose close waits for the process
class _wrap_close:
    def __init__(self, stream, proc):
        self._stream = stream
        self._proc = proc
    def __getattr__(self, name):
        return getattr(self._stream, name)
    def __iter__(self):
        return iter(self._stream)
```
`popen()`返回了一个`_wrap_close`对象，而后者仅仅是一个Iterable，而不是Iterator（没有定义`__next__()`）。然而，`_wrap_close`却定义了`__getattr__()`魔法方法，这样所有其他找不到的属性、方法就会传递给`self._stream`对象，而这个对象有`__next__()`方法。这就解释了为什么`r.__next__()`能调用成功。

所以，**Python对于魔法方法的调用是基于这个类有没有定义此方法吗？**

答案是肯定的，查看Python源码中`next()`内建函数的实现，可以看到下面的代码：
```c++
#define PyIter_Check(obj) \
    (Py_TYPE(obj)->tp_iternext != NULL && \
     Py_TYPE(obj)->tp_iternext != &_PyObject_NextNotImplemented)
```
判断一个`obj`是不是迭代器，是基于`Py_TYPE(obj)`是否有`__next__()`方法，而不是`obj`本身。`__next__()`如此，其他魔法方法也是一样。

问题解决了，我们可以得到下面的推论：

> **动态修改（或者叫monkey patch）一个实例的魔法方法，是不生效的。**

看下面的例子：
```python
>>> class Foo: pass
...    foo = Foo()
>>> foo.__str__ = lambda: '42'    # <= 企图修改foo的__str__方法
>>> print(foo)
<__main__.Foo object at 0x1024f7fd0>
```
`foo`的字符串依然是原来的默认值，没有改变。要想改变，必须修改`Foo.__str__`方法。

下面这段是额外的思考，可能比较绕：

再回头去看最开始的例子，这个问题之所以奇怪，是因为它用了`__getattr__()`让**实例**获得了并不存在于**类**中的属性。也就是说，原来的**类**并没有获得这些额外的属性。而魔法行为的判断是基于**类**中是否有这个魔法方法。这两件事合起来看，那我是不是可以通过**元类**中的`__getattr__()`方法让**类**获得本不属于它的魔法方法，继而使得**实例**具有某些行为呢？说干就干：

```python
class IterMeta(type):
    def __getattr__(self, name):
        if name == '__next__':
            return lambda x: 42
        return super().__getattr__(name)

class Foo(metaclass=IterMeta):
    pass

foo = Foo()
next(foo)
# TypeError: 'Foo' object is not an iterator
foo.__next__()
# AttributeError: 'Foo' object has no attribute '__next__'
Foo.__next__(foo)
# 42
Foo.__next__ = lambda x: 42
next(foo)
# 42
```

不能！明明`Foo`能获取到`__next__()`属性，看来`(Py_TYPE(obj)->tp_iternext`并不会触发`__getattr__`。

 我用Python的时间不可谓不短，也自认对Python的语言特性比较了解了，但Python却总能时不时让我意外一下，这是什么情况？