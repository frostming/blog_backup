---
author: Frost Ming
category: 编程
date: 2019-04-30 10:03:07.109612
description: HDIW系列文章之二
image: //static.frostming.com/images/2019-04-how_does_it_work.jpg
tags:
- Python
- howdoesitworks
- 源码阅读
title: How does it work? -- threading.Condition
---

继两年前的[上一篇文章](https://frostming.com/2017/08-28/how-does-it-work-with-metaclass)之后，不靠谱博主终于想起了*How does it work*这个坑。主要是近期也没有遇到可值得分享的「精巧」的实现。之前其实也过了一遍`threading`模块的源码，对里面的各种锁也只是有个大概印象，并且它们之前非常像，很容易让人confusing。这次碰到实际需要，于是仔细看了一下源码，发现还是有很多搞头的。当然，你只是使用的话照着例子用就好了不会出错，但还是值得花点工夫弄清里面的原理。


## Condition的使用示例

下面是我随便从网上搜来的代码片段

```python
import threading, time
class Hider(threading.Thread):
    def __init__(self, cond, name):
        super(Hider, self).__init__()
        self.cond = cond
        self.name = name
    def run(self):
        time.sleep(1) #确保先运行Seeker中的方法
        self.cond.acquire() #b
        print self.name + ': 我已经把眼睛蒙上了'
        self.cond.notify()
        self.cond.wait() #c
                         #f
        print self.name + ': 我找到你了 ~_~'
        self.cond.notify()
        self.cond.release()
                            #g
        print self.name + ': 我赢了'   #h
class Seeker(threading.Thread):
    def __init__(self, cond, name):
        super(Seeker, self).__init__()
        self.cond = cond
        self.name = name
    def run(self):
        self.cond.acquire()
        self.cond.wait()    #a    #释放对琐的占用，同时线程挂起在这里，直到被notify并重新占有琐。
                            #d
        print self.name + ': 我已经藏好了，你快来找我吧'
        self.cond.notify()
        self.cond.wait()    #e
                            #h
        self.cond.release()
        print self.name + ': 被你找到了，哎~~~'
cond = threading.Condition()
seeker = Seeker(cond, 'seeker')
hider = Hider(cond, 'hider')
seeker.start()
hider.start()
```
这里用的捉迷藏，换成聊天也可以。其实就是两个线程间的同步，一应一答。一个线程执行完操作以后通知另一方并等待应答。下面我们要解决一些问题：

1. 它跟`Lock`有什么区别？
2. 可以注意到双方动作前都`acquire`了同一个`Condition`，这样不阻塞吗？
3. 为什么一定要`acquire`？我换成获取一个普通的`Lock`行吗？

## Condition源码分析

`Condition`的初始化方法为`Condition(lock)`，其中`lock`不传的话默认是一个`RLock()`，即可重入锁，关于锁的区别比较好理解，这里就不啰嗦了。初始完之后会把传入的锁存为属性，然后`Condition`的`acquire`和`release`就只是对这个锁的获取释放而已。所以：

```python
lock = Lock()
cond = Condition(lock)
cond.acquire()
# 换成lock.acquire()完全等价，release类似
```
到此为止还看不出为何要用`Condition`而不用`Lock`，关键是下面两个方法`wait`和`notify`，我把代码完整贴出附上自己的注释：
```python
def wait(self, timeout=None):
    if not self._is_owned():    # 必须先获取self._lock
        raise RuntimeError("cannot wait on un-acquired lock")
    waiter = _allocate_lock()       # 新建一个锁
    waiter.acquire()    # 获取刚刚新建的锁
    self._waiters.append(waiter)    # 加入waiters列表
    saved_state = self._release_save()    # 这里释放了self._lock
    gotit = False
    try:    # restore state no matter what (e.g., KeyboardInterrupt)
        if timeout is None:
            waiter.acquire()    # 再次获取新建的锁
            gotit = True
        else:
            if timeout > 0:
                gotit = waiter.acquire(True, timeout)   # 等待时间后返回
            else:
                gotit = waiter.acquire(False)   # timeout == 0, 立即返回
        return gotit
    finally:
        self._acquire_restore(saved_state)    # 重新恢复self._lock状态
        if not gotit:   # 如果是非阻塞的(timeout != None)
            try:
                self._waiters.remove(waiter)    # 从waiters列表删除
            except ValueError:
                pass
```
果然talk is cheap, show me the code，看了代码就一目了然了。可以看到`self._lock`（就是初始化时传入的那个锁）在第7行之前是占用状态的，此时其他线程不可插入，然后整个try-block里`self._lock`是释放状态可被其他线程获取。通过再次获取同一个waiter锁达到了阻塞的效果，这样看起来就像是新加入了一个等待者在等待某个事件。等待的这个事件，就是其他线程用同一个`Condition`实例调用的`notify`方法：
```python
def notify(self, n=1):
    if not self._is_owned():
        raise RuntimeError("cannot notify on un-acquired lock")
    all_waiters = self._waiters   # 获取所有等待的锁
    waiters_to_notify = _deque(_islice(all_waiters, n))    # 只选给定数量的等待者，如果是notify_all方法则是全部
    if not waiters_to_notify:
        return
    for waiter in waiters_to_notify:
        waiter.release()    # 
        try:
            all_waiters.remove(waiter)
        except ValueError:
            pass
```

可以看到`notify`方法全程都拥有锁`self._lock`，这样保证了只有Notify完成之后对方才能下一步动作。调用时序如下：
![Snipaste_2019-04-30_18-02-42.png](//static.frostming.com/images/2019-04-Snipaste_2019-04-30_18-02-42.png)
总结来说的话，就是只有`wait()`方法能主动释放锁，而`notify()`不能，所以waiter线程一定要先启动，防止发生死锁。

## Event与Condition

`threading`中还有一个`Event`，与`Condition`非常类似。区别在于前者等待、监听某个值`is_set()`为真，而后者只是一个通知等待的模型。并且`Event`中监听值翻转以后，正是通过`Condition`去通知等待者的。`Event`变成`set`以后，就「失效」了，要手动`clear`一次才能继续使用用，而`Condition`是可以无限`wait`, `notify`循环的。

```python
class Event:
    def set(self):
        with self._cond:
            self._flag = True
            self._cond.notify_all()
```
其实，`Condition`也包含一个`wait_for(eval_function, timeout)`方法，用来等待某函数的返回值为真。这个方法用起来和`Event`的作用是很像的，你可以理解为`Event`只是提供了一个包装好了的`Condition`。