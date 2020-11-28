---
category: 编程
date: 2019-11-25 14:37:05.729331
description: 一个简单但很多人没注意的细节
image: https://images.unsplash.com/photo-1554252116-30abdf759321?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1350&q=80
tags:
- git
template: post
title: 给你的 Git commit 加上绿勾
---

今天无事翻看了几个Python开发者的Github，却发现大多数人的Git commit列表都是白茫茫一片。
![no-sign.png](//static.frostming.com/images/2019-11-no-sign.png)
大家乍一眼可能看不出有什么问题，那么看下面这张图就明白了：
![has-sign.png](//static.frostming.com/images/2019-11-has-sign.png)
没错，每条commit后面都有一个**Verified**绿标，我是一个对这些东西有偏执的喜好的人，只要见过别人有，那自己也一定要有。大多数人都会去追求全站HTTPS的那个绿色对勾（虽然新版Chrome变成一把暗淡的锁让人失去许多动力），但并没有那么多人会去追求这个commit的绿标。之前听[捕蛇者说](https://pythonhunter.org)的时候也发现，有时候一些你认为习以为常的知识，很多人并不知晓。所以我觉得自己知道的东西，一定要多分享。
> 勿以善小而不为，勿以知识微小而不分享

## 这个绿标是个啥？

大家可能都知道，安装git之后第一件事就是用
```bash
$ git config set --global user.name <username>
$ git config set --global user.email <email>
```
设置你的用户名和邮箱，这些信息会显示在提交历史(`git log`)里面，表示这个提交的作者信息。但你发现了吗，你是可以随意设置邮箱和用户名的，我甚至可以设成Linus Torvalds的个人信息，毕竟这些东西都是公开可查的，那么难道就变成Linus提交的了吗？反过来，你可能工作的环境不止一个，每个环境都有不同的邮箱，工作环境用工作邮箱，个人环境用个人邮箱，那么当我在这两种环境上都提交调同一个Github仓库时，别人如何知道都是同一个人？

这个绿标就是证明**我是我**、**别人不是我**的东西，这些提交其实是用个人专属的PGP密钥签名过的。PGP是一种加密算法，使用非对称的密钥，而产生这种密钥的软件是GPG(Gnu PG)。关于PGP和GPG我也不是专家只能到此为止，大家可以阅读文末的参考链接以了解更多。

这个签名，起到了认证身份的作用，所以无论我用的是什么邮箱，只要带上了这个签名，那么这个提交就是我本人做出的，别人是无法伪造的。你参加开源贡献时，附上这个小小的绿标，也会显得你更加专业。

## 生成GPG密钥

一般Linux系统都已经自带gpg软件，输入`gpg --help`可以查看你是否已经安装，如果没有安装可以用你系统的包管理器来安装。首先在终端输入：
```bash
$ gpg --full-generate-key
```
然后按照提示输入信息，密钥类型使用默认的`RSA and RSA`即可。密钥长度推荐使用默认的4096，然后输入你的个人信息，这样密钥就会绑定到你的邮箱，要使用和Git提交相同的邮箱地址。最后输入一段密码，用来提取这个密钥。这样一个GPG密钥就生成好了，可以输入
```bash
$ gpg --list-secret-keys --keyid-format LONG
/Users/hubot/.gnupg/secring.gpg
------------------------------------
sec   4096R/3AA5C34371567BD2 2016-03-10 [expires: 2017-03-10]
uid                          Hubot 
ssb   4096R/42B317FD4BA89E7A 2016-03-10
```
来查看你的密钥，在本例中此密钥的ID是`3AA5C34371567BD2`。接下来，我们需要获取公钥值：
```bash
$ gpg --armor --export 3AA5C34371567BD2
-----BEGIN PGP PUBLIC KEY BLOCK-----
...
-----END PGP PUBLIC KEY BLOCK-----
```
将公钥的内容复制到剪贴板以备后续使用。

在你的Github中，点击头像-Settings-SSH and GPG keys，然后点击`New GPG key`，将复制好的公钥内容粘贴进去即可。

## Git提交启用签名

在提交时启用签名很简单，只要在`git commimt`命令中加上`-S`选项即可。如果git提示找不到gpg程序，很可能因为你的gpg可执行程序不在`PATH`中，使用
```bash
$ git config set gpg.program <path_to_gpg>
```
来指定gpg程序位置。现在`git push`你的提交，你就会在commit列表中发现提交已经加上了这个绿标了。

每次提交都要加上`-S`未免麻烦，你也可以默认启用GPG签名：
```bash
$ git config --global commit.gpgsign true
```
嗯，很好，每次都会自动加上签名了，但是，你会发现签名的时候都会弹出一个prompt输入密码。甚至你使用IDE集成的git的时候也会弹出这么个终端，这也太烦了，有没有不用输密码的方法？我目前也只在Mac系统上找到了解决方法，因为这个GPG key的密码可以保存到Mac钥匙串中，你只需要安装`gpg-suite`即可，使用homebrew安装起来也很简单：
```bash
$ brew cask install gpg-suite
```

到目前为止我们好像把Windows忘了，没有问题，你只需要安装一个[Gpg4win](https://gpg4win.org/)GUI客户端就可以了（其实Git for windows会自带一个GPG，但它只是一个命令行程序，这样对IDE不太友好），注意你需要确保git配置的gpg程序指向Gpg4win下面的gpg(`Gpg4win的程序路径/bin/gpg.exe`)。这个GUI客户端虽然不会记住密码，但起码它弹出的是一个GUI窗口提示输入密码，可以和IDE完美工作。只是在提交的时候需要输入一次密码，也不算很大的负担，反而增添了些许仪式感。

一般情况下，我会在每个会提交到我的Github仓库的机器产都生成一个密钥，然后加到Github账户中。

## 更多关于PGP加密

对自己的身份严格认证，对自己的信息加密是一个很好的习惯，GPG key除了可以做提交签名之外，也可以加解密消息，对通信进行安全加固，把公钥发给对方，别人用这个公钥加密，你收到后用私钥解密。互联网上就有这么一款产品叫 https://keybase.io ，可以分享自己的PGP密钥，作为自己的一种指纹信息，推荐大家都去注册一下，我的个人的指纹是[`7B28 4C8F CC08 5EFF`](https://keybase.io/frostming)，我们来加密聊天吧！（然并卵，日常还不都在用微信裸奔聊天）。

## 参考链接

* [PGP](https://zh.wikipedia.org/zh-hans/PGP)
* [Generating a new GPG key - GitHub Help](https://help.github.com/en/github/authenticating-to-github/generating-a-new-gpg-key)
* [Adding a new GPG key to your GitHub account - GitHub Help](https://help.github.com/en/github/authenticating-to-github/adding-a-new-gpg-key-to-your-github-account)
* [Signing Commits - GitHub Help](https://help.github.com/en/github/authenticating-to-github/signing-commits)