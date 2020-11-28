---
category: 编程
date: 2019-09-01 08:36:32.647769
description: 又一篇Pipenv文章
image: //static.frostming.com/images/2018-09-pipenv.jpg
tags:
- Python
- Packaging
template: post
title: Pipenv有什么问题
---

这不是我第一次写Pipenv相关的文章，也相信不是最后一次，前两篇我用的是英文，（浅陋地）分析了Pipenv和Poetry的优劣，至今仍是我博客访问量最高的文章。今天是因为在知乎上看到两位朋友写的两篇文章（链接我放在文末了），吐槽了一通以后推荐大家不要使用Pipenv。说实话，作为核心维护者之一我是有点心酸的，因为他们说的那些问题的确都存在。在本文中我希望从一个核心维护者的角度，总结一下Pipenv存在的问题，作为一个告解。

从我关注Issues列表以来，我脑中能回想起来的，抱怨频率最高的，也是最影响用户体验的，有几个问题：

## 1. Lock时间长

用户经常抱怨`pipenv lock`的时间长，特别是涉及到一些科学计算的库时，如`numpy`, `sklearn`, `tensorflow`，会慢得让你怀疑人生。`pipenv lock`其实做的就是依赖解析，而慢的原因是，Pipenv需要下载所有的安装包来计算它们的哈希值，要命的是，像`numpy`这种库，一个版本就有[17个包](https://pypi.org/project/numpy/#files)，每个包的大小是10M~20M不等，总共下载的大小就有300多M左右。也有人提PR希望修改这个逻辑，但后来都不了了之。

Issue传送门：https://github.com/pypa/pipenv/issues/3827

PR传送门：https://github.com/pypa/pipenv/pull/3830

## 2. 命令及选项的结果不符合预期

李辉老师的文章里面列举了安装、卸载、更新包的问题，我这里先回复一下，其实它们都是同一个问题：`pipenv update`不能保护其他包不被更新。并且`--keep-outdated`和`--selective-upgrade`这两个选项意义不明容易让用户搞错。

其实`--keep-outdated`有一次[大修复](https://github.com/pypa/pipenv/pull/3768)，**只是还没有发布到新版本**，所以用github上的master分支是没问题的。我在这里解释一下`--keep-outdated`和`--selective-update`这两个选项的作用：`--keep-outdated`意思是更新Pipfile.lock时，不会删除**已经不需要**的依赖。这对于产生一个跨平台的lock文件非常有用，因为有些仅Windows需要的依赖，你在Windows上生成Pipfile.lock时会有，而换到Linux上再执行`pipenv lock`时就没有了。这个选项时针对Pipfile.lock更新的，而`--selective-upgrade`是针对安装过程的，它会控制pip安装包时，只在有必要的时候升级次级依赖的版本。这里又涉及到一个逻辑的不统一：用`pipenv install xxx`安装包的时候会先调用`pip install xxx`，并用pip的机制去更新依赖，再用Pipenv lock去锁定依赖。理想情况下，依赖解析器应该唯一，应该通过Pipenv解析完了以后再统一安装。

除此之外，其他的一些不符合预期的命令和混乱的选项有：

* `pipenv install`有`--skip-lock`, `--ignore-pipfile`, `--deploy`，此外还有不更新Pipfile.lock的`pipenv sync`命令，有谁能一眼区分出它们各自的作用？
* 安装普通依赖用`pipenv install`，安装普通和开发依赖用`pipenv install --dev`，但`pipenv lock`永远一起解析普通和开发依赖，有没有`--dev`都一样。然而`pipenv lock -r`是生成普通依赖，`pipenv lock -r --dev`是仅生成开发依赖。
* 接上一条，`pipenv uninstall --all`是删除当前虚拟环境中所有已安装的包，**不更新Pipfile**，而`pipenv uninstall --all-dev`是删除所有开发的依赖，**更新Pipfile**。

我说的这些问题，都对应着许多Issue，我就(lan)不(de)一一列举了。

## 3. 无法解析依赖

这一点也是在[Poetry的文档中](https://link.zhihu.com/?target=https://github.com/sdispater/poetry#dependency-resolution)作为反面教材抨击的，其根本原因是，Pipenv不能自动回溯依赖的版本来满足依赖的限制。比方说A包依赖C<1.0，而B包的1.x版本依赖C<1.0而2.0版本依赖C>=1.0，那么你在Pipfile中同时包含A, B时就会解析失败：Pipenv只会选用B的最新版本，在依赖不能满足时不会尝试旧版本。

Pipenv解析依赖其实用的是[piptools](https://github.com/jazzband/pip-tools/)，后者不能解析的Pipenv也不能。好消息是Pipenv维护小组做了一个新的依赖解析器[passa](https://github.com/sarugaku/passa)，还在试验阶段，它能解决这个问题，未来会替代成为Pipenv的依赖解析器。

## 4. 怎么还不release，以及其他的开发流程的问题

董伟明老师说到BDFL，没错，Kenneth Reitz曾经设计出了一套PEEP的流程，并把自己放在BDFL的位置上。但是，由于他本人对开源热情的消退，他已经实际上[退出了这个位置](https://github.com/pypa/pipenv/blob/master/peeps/PEEP-003.md)。但是PEEP的机制仍然存在：所有Behavior change必须先落地到PEEP文档上，其实PEEP不难写，能说清楚就行了，但是从这个机制创立至今，仅有5个PEEP被接受且**没有外部贡献者的PEEP**，这其中，又仅有2个涉及机制变化的PEEP真正落地。

其实Pipenv的问题数量不算多，维护者的人力对比Poetry也不见得少，关键问题就是上述的几个严重影响用户体验的问题，或者问题修复了却迟迟不发布新版。

不止一个人，也不止一次有人抱怨发布无限延期的问题，就快变成陈永仁那个「说好了三年，三年之后又三年，如今都快十年了！」的梗了，我在这里也解释一下。现在核心维护者主要有Dan Ryan(techalchemy), Tsuping Chong(uranusjr)和我，其中只有Dan有PyPI的权限，我其实说白了就是个「比较勤奋的Contributor」的角色。而Dan因为私事缠身无暇顾及开源工作。但好消息是他自称事情已处理得差不多，会慢慢跟上进度。虽然我知道催促一个维护者在开源社区中不是一个礼貌的做法，但我也理解大家的心情，以及因此而心灰意冷弃用的用户，所以我恳请大家，宽容一些，静静等待吧。

> 为什么不开放权限给其他人？比如说我。

Dan是一个严谨的人，他希望亲自过一遍改动日志，润色完了以后再发布，所以还需要等待一些日子。他也对新特性的态度非常保守，总是害怕影响regression，破坏已有用户的体验。具体可以看看[这个PR](https://github.com/pypa/pipenv/pull/3830)里面的回复，这一点我不能认同，但也无可指责，毕竟他承担了Kenneth Reitz以后90%的开发工作，其中有些部分确实非常棘手和麻烦。

作为维护者之一，我的想法是，因为master上已经积压了太多的改动，先等Dan回来把这次新版本发布了，回到正轨以后，我会开始针对以上我提到的问题，编写PEEP，引入Deprecation机制，不去回避Breaking change。

## 5. Poetry如何呢

最后还是提一下Poetry吧。Python的工作流工具，其实无非是解决三个方面的问题：虚拟环境管理、依赖管理、打包发布。Pipenv只包含前两项，比重是50%:50%，而Poetry同时包括三项，比重是20%:40%:40%。所以当我用惯了Pipenv切换到Poetry时会非常不习惯——它对于虚拟环境的控制太弱了：我无法知道我用的是哪个环境，路径是什么，也不能随心所欲地删除、清理、指定虚拟环境的位置。Pipenv的依赖解析器确实存在很多问题，但Poetry的也离完美有一段距离。而且Poetry负责的打包发布部分，也不是最好的。所以我认为Poetry也没有大家推荐的那么好。如果Pipenv没有满足你的要求，那么虚拟环境管理方面我推荐[virtualenvwrapper](https://virtualenvwrapper.readthedocs.io/)+[direnv](https://www.baidu.com/link?url=ZLnHDmLvp9jeNCDgIzlPNZUbONmmIC5VaeqUuHAiHWG&wd=&eqid=8c60d2c7001f275e000000065d6b811e)（这两个的最大问题是不支持Windows)，依赖解析方面我推荐[piptools](https://github.com/jazzband/pip-tools/)，打包发布还是用setuptools。

## 相关阅读

1. [李辉：不要用Pipenv](https://zhuanlan.zhihu.com/p/80478490)
2. [董伟明：也谈「不要用 Pipenv」](https://zhuanlan.zhihu.com/p/80683249)
3. [Python packaging war: Pipenv vs. Poetry](https://frostming.com/2018/05-15/pipenv-vs-poetry)
4. [A deeper look into Pipenv and Poetry](https://frostming.com/2019/01-04/pipenv-poetry)