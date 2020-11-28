---
category: 编程
date: 2019-04-24 03:14:48.705965
description: Vue.js + Flask前后端分离
image: //static.frostming.com/images/2019-04-admin.jpg
tags:
- Python
- 博客
- Vue
template: post
title: 全新后台上线
---

最近几周空余时间都在做博客后台的重构，主要是因为之前匆匆上线的后台略显简陋。这一次重构就是奔着前后端分离去的，也是为了练练自己的前端技能。

主体框架使用了国人的[Vue Element Admin](https://github.com/PanJiaChen/vue-element-admin)，框架本身提供了丰富的机制，我做了大量的裁剪，主要保留了文章列表、文章编辑等模块，其他亮点有：

* 主题颜色实时显示更新
* 配置更新立即生效
* 文章配置默认隐藏，更专注于写作
* 全局国际化，选择语言立即生效
* 独立集成工具页面，方便集成各种三方服务，后续添加中

### 后台样式预览
![Snipaste_2019-04-24_11-43-43.png](//static.frostming.com/images/2019-04-Snipaste_2019-04-24_11-43-43.png)
![Snipaste_2019-04-24_11-44-03.png](//static.frostming.com/images/2019-04-Snipaste_2019-04-24_11-44-03.png)
![Snipaste_2019-04-24_11-44-13.png](//static.frostming.com/images/2019-04-Snipaste_2019-04-24_11-44-13.png)

### 后续改进

完成了后台改造，前台改造也在计划中了，不过暂时还没必要用前后端分离的方法，主要是改下样式。

就酱