---
author: Frost Ming
category: 编程
date: 2020-03-10 06:20:05.684060
description: ''
image: https://images.unsplash.com/photo-1516321497487-e288fb19713f?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1350&q=80
tags:
- 社区
title: 如何让你的开源项目看上去像那么回事
---

> 题按：本文写给那些有志于加入到开源的世界的人们，主要以我的主力语言Python作为例子，但可适用于任何语言。

<!--more-->

***开源并不等于免费和开放源代码而已***

相信各位搬砖工在公司里都有面对过屎山的经历，千奇百怪的编码风格、神出鬼没的注释和「卧槽，这也行」的骚操作充斥其间，我相信就算是FLAGM大厂也是如此。与之相反，如果你要将你的项目开源，对编码质量有很高的要求。而除了代码，一个开源的项目还有一些杂七杂八的东西，这些可能大家并不是很注意，但却能让你的开源项目「看上去像那么回事」。



### 一个漂亮的README



README是开源项目的门面，一个优秀的README，至少要包含以下方面：

* 简单介绍项目是做什么的
* 项目有什么特点，吸引用户来用
* 安装、编译的方法
* 最简单的Quick start示例
* License

README并不等同于文档（除非你没有专门的文档网站），它不需要详细到API Reference，只需要几个简单，吸引人的例子，和安装使用说明。

其他可以给README加分的东西有：

* **Badge**，包括包管理、CI状态、覆盖率、代码质量，这些都有badge可以用，可以到[Shields.io](https://shields.io/)选择你想要的，但不能放太多，6个以下为宜。不能README没写多少，badge一大坨。
* **一个图片或视频演示**，相关工具及服务有：
  * [Carbon](https://carbon.now.sh/?)或它的命令行版本——创建漂亮的代码高亮截图
  * [Asciinema](https://asciinema.org/)——创建终端动画视频
  * [Termtosvg](https://nbedos.github.io/termtosvg/)——录制终端动画为svg格式，也可以渲染成Asciinema的格式
* **一个可供用户预览的Demo**
  * 如果是应用类，可以做成网站放出
  * 如果是工具类，可以做成云shell的形式，有以下服务：
    * [Repl.it](https://repl.it/)
    * [Google Cloud Shell](https://ssh.cloud.google.com/cloudshell/editor)
    * [Google Colab](https://colab.research.google.com/)——分享Jupyter notebook
    * [https://rootnroll.com](https://rootnroll.com/)——类似Repl.it
    * [Heroku一键部署](https://devcenter.heroku.com/articles/heroku-button)


其他README参考资源：

* https://www.makeareadme.com/


### 开源社区相关文件

要把你的项目开源，还有一些杂七杂八的文件，这些GitHub上的[Community](https://github.com/frostming/pdm/community)页面都有展示：

* **LICENSE**——最最最重要的，没放这个文件，别人是不能用你的源代码的。有N种许可证可以选，具体的差异不赘述，大部分情况我都是默认用MIT。
* **Code of conduct**——行为准则，用于约束贡献者、用户及项目相关的讨论规范，避免一些不必要的争端，这个GitHub也有默认模板，或者去其他开源项目抄，都可以。
* **CONTRIBUTING.md**——贡献指南，包括如何设置开发环境，如何提交issue，PR，如何跑测试，以及代码的规范等等。
* **Issue template/PR template**——Issue和PR的提交模板，有太多用户不知如何提一个好的问题，经常信息不全、只言片语，就指望你为他排忧解难，怎么解？用水晶球吗？所以放一个完善的Issue模板，把待填的信息留空，可以很大程度避免这种情况。



### 项目代码相关文件

一千个人有一千种编码风格，除了在贡献指南中文字约定之外，我们还需要一些强制措施来保证代码的一致性。

* **持续集成**——非常重要，如果你的开源项目没有CI的话会显得相当不专业，配置一个CI服务，把Badge贴到README里面，一目了然，持续集成包括

  * 自动化测试Testing
  * 代码检查Linting
  * 自动发布Release

  可选择的服务有TravisCI, Jenkins, Appveyor, Azure Pipelines, GitHub Actions。其中（个人认为）功能最强大的是Azure Pipelines，但最容易上手的是GitHub Actions，在这里我最推荐GitHub Actions。

  持续集成通常用来兜底，作为PR通过的强制指标之一。

* **[Pre-commit](https://pre-commit.com/)** ——主要用来代码格式化和运行Linter，如果开发者安装了pre-commit钩子，这些动作会在提交前运行。虽然Linting经常包括在持续集成中了，但Pre-commit检查仍然有必要，且更快捷，能更早的发现问题，因为跑一次CI短则几分钟，长则能达到一小时，你肯定不想等这么久结果发现代码中有个错字吧。

* **各种Linter, formatter的配置文件**，用来统一配置。我常用的此类工具有：
    * [black](https://github.com/psf/black)——代码格式化
    * [flake8](https://pypi.org/project/flake8/)——代码检查
    * [isort](https://github.com/timothycrosley/isort)——import语句排序

* **[Editorconfig](https://editorconfig.org/)** ——统一化一些编辑器的设定，包括换行符统一、编码统一、Tab/空格统一，终极争端解决器。当然前提是代码编辑器支持Editorconfig。

对于一些需要工具支持的文件，需要在CONTRIBUTING.md中要求开发者安装。否则不给过PR，哼。

