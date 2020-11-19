---
author: null
category: 编程
date: 2020-11-19 03:06:00.707508
description: 利用GitHub Action在你的个人README加魔法
image: ''
tags:
- github
title: 我是如何摸鱼的
---

可能是我之前star过几个GitHub Profile项目，现在我GitHub首页右侧推荐总是时不时有类似的Repo出现。

有一类Profile比较特殊，它们有社区互动模块，比如：

- [国际象棋](https://github.com/timburgan/timburgan)
- [四子棋](https://github.com/JonathanGin52/JonathanGin52)
- [词云统计](https://github.com/JessicaLim8/JessicaLim8)
- [摇骰子](https://github.com/benjaminsampica/benjaminsampica)

受之启发，我也花mo了yu半天时间撸了一个五子棋游戏放在我的Profile中。现在棋盘只有9×9，高手对决可能无法分胜负，但已经留了空间能灵活改变。

<!--more-->

![image-20201119105305918](https://static.frostming.com/images/image-20201119105305918.png)

简单说下这些带互动部分的Profile的实现原理吧。其实都是依靠强大的GitHub Actions。

1. 用户点击棋盘上的空白，提交一个issue，包含预设的标题、内容和label，这些信息全都能放在一个URL里，非常方便。

2. Issue提交后，会触发一个GitHub Action，运行脚本，读取Issue的标题，取出要进行的动作，改变棋盘。这个action的触发器是这样的：

   ```yaml
   on:
     issues:
       types: [opened]
   
   jobs:
     move:
       runs-on: ubuntu-latest
       if: startsWith(github.event.issue.title, 'gomoku|')
   ```

3. 将此动作的元数据和游戏统计信息写到Repo中，重新生成README，提交、push。Push信息中带上`Close #<issue_num>`把Issue关掉。

总得来说GitHub Actions还是挺好玩的，自从这个功能开放以来，各种骚操作层出不穷。特别是Travis CI开始掉链子，大家纷纷转向GitHub Actions。怎样，来我主页下个棋吧？