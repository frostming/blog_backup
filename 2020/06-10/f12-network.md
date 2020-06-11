---
author: Frost Ming
category: 编程
date: 2020-06-10 05:10:32.233243
description: F12 Network篇
image: //static.frostming.com/images/2020-06-chrome-devtools-lg.webp
tags:
- Web
- 入门
title: Chrome开发者工具指北
---

Chrome Dev Tools，Chrome开发者工具，俗称F12。其实不仅在Chrome上有，基本上所有的现代浏览器都带这个工具。它是调整样式、调试JS、查看前后端收发数据的不二神器。

<!--more-->

在Chrome浏览器中呼出F12有三种方法：

1. 右上角三个点按钮调出菜单——更多工具——开发者工具(Ctrl + Shift + I)
2. 顾名思义，键盘快捷键<kbd>F12</kbd>一键呼出
3. 在页面元素上右键点击——审查元素，或者叫检查

![image-20200610100929539](https://static.frostming.com/images/image-20200610100929539.png)

呼出以后会显示在页面的下方，如果觉得这样太扁不方便看信息，可以点右上角三个点的按钮调整布局，分别是新窗口打开、靠在左侧、靠在下方，靠在右侧：

![image-20200610101110639](https://static.frostming.com/images/image-20200610101110639.png)

可以看到工具的顶栏有很多标签：本文先介绍最常用也是最重要的「Network」页，其他标签将在后续文章中介绍。

## 预备知识：HTTP请求过程

![image-20200610105753662](https://static.frostming.com/images/image-20200610105753662.png)

这是浏览器和后端服务器之间的数据流动示意图

1. 浏览器和服务器之间可能隔了千山万水，相互之间的数据交换必须由HTTP请求——响应完成（图中箭头）
2. 一个页面中包含的HTML, CSS, JavaScript均由浏览器这边处理，后端（Django）统统不认识这些文件，当成普通文本看待。
3. 请求体是浏览器生成给服务器读的，响应体是由服务器生成给浏览器读的，只是这个响应体可能是HTML页面、可能是文件、可能是JSON而已。

而浏览器和服务器之间传送了什么数据，对于排查问题是非常有用的，Network在这里就相当于路口的监控，进来了谁，出去了谁，一目了然。如果请求的数据是对的而行为不正确，那肯定是服务器的问题；反之如果发的数据就是错的，那就是页面的问题。这样一下就可以把排查的范围缩小一半。所以不要再出了问题一个劲盯着无关的地方大眼瞪小眼。F12打开先看监控，OK?

一个HTTP请求主要包含以下部分：

1. Method: 请求的方法，是GET还是POST或者其他
2. URL: 请求的地址，可能还包含URL参数（形如`?key1=value1&key2=value2`)
3. Headers: 请求的头部，包含一些请求的元数据。
4. Body: 请求体，发送的请求内容

而一个HTTP响应主要包含以下部分：

1. Headers: 响应的头部，包含一些响应的元数据。
2. Body: 响应体，返回的响应内容

## Network面板能看啥

![image-20200610114145824](https://static.frostming.com/images/image-20200610114145824.png)

打开Network面板，然后刷新页面，可以看到当前页面发送的所有请求，其中大部分是加载静态文件

* Method: 请求方法
* Status: 返回的状态码
* Size: 响应大小，如果是带"cache"字眼说明没有请求到后端，而是从缓存中获得的[^1]
* Time: 载入耗时

从这个列表，加载了哪些文件，是否有加载失败，加载耗时如何都一目了然。有了这些信息能做的事情就多了：

* 分析页面响应速度的瓶颈，优化渲染速度
* 查看与后端通信成功情况，方便Debug
* 查看页面的数据来源，以便仿造请求，爬虫利器

而上图中高亮的类别可以精细过滤请求类型，XHR是专门查看Ajax请求的，JS, CSS, Img则可以分别查看这些静态文件的加载情况。

## 查看请求详情

举例来说，比如现在我开发了博客的评论功能，想知道发送评论是否正常工作。那么打开Network面板，在页面中添加一条评论并提交，在Network中就应该能看到一条请求的记录，为防止页面刷新记录丢失，可以勾选上Preserve框：

![image-20200610115840043](https://static.frostming.com/images/image-20200610115840043.png)

如果列表已经太多内容可以点击清空按钮<img src="https://static.frostming.com/images/image-20200610121959116.png">清空当前列表。可以看到`comment`请求方法是`POST`，已经返回200成功了。点选这条记录，可以在右侧看到请求响应的详情：

![image-20200610121445910](https://static.frostming.com/images/image-20200610121445910.png)



从上到下依次是：

* General: 请求总体信息，URL，Method，返回状态码等
* Response Headers: 响应头
* Request Headers: 请求头
* Request Body: 请求体，如果是form表单则显示发送表单的内容

这样你就可以知道浏览器发了什么给服务器，又从服务器收到了什么内容。

## Network的其他强大功能

![image-20200610121833101](https://static.frostming.com/images/image-20200610121833101.png)

在请求记录上右键点击可调出菜单，可以做很多事情。比如在新标签打开、清除浏览器缓存/Cookies、将连接复制为PowerShell脚本、fetch调用、curl命令等等。

此外在Network面板中按<kbd>Ctrl</kbd><kbd>F</kbd>，可以搜索某个具体的数据内容，是在哪一个请求中返回的，这无疑对写爬虫有巨大帮助。

[^1]: 这就是为什么更新了后端静态文件没有生效的原因。解决方法很简单：<kbd>Ctrl</kbd><kbd>F5</kbd>可以强制刷新，或者在Network面板右键点击该文件的记录然后选择"Clear browser cache"