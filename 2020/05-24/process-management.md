---
author: Frost Ming
category: 编程
date: 2020-05-24 13:17:48.286258
description: 新手问题Sticker系列
image: https://images.unsplash.com/photo-1522198798025-edbf00dabd6b?ixlib=rb-1.2.1&ixid=eyJhcHBfaWQiOjEyMDd9&auto=format&fit=crop&w=1350&q=80
tags:
- 入门
title: Web 服务的进程托管
---

> 「入门」标签的文章是我写给新手入门者的<del>解疑文章</del>水文，也是给自己的知识有个地方做做梳理。如果本文对你没有帮助，可以不看。

<!--more-->

在开发Web服务（或者叫App，后文中App和服务概念等同）的时候，最后一步就是启动服务器运行你的App。在大部分的教程中，这里的选择通常是uwsgi或者gunicorn。你会发现，它运行起来以后，会占用你当前的一个终端会话，进入「长运行模式」，就像这样：

```console
[2020-05-23 22:54:57 +0800] [13077] [INFO] Starting gunicorn 20.0.4
[2020-05-23 22:54:57 +0800] [13077] [INFO] Listening at: unix:/tmp/***.socket (13077)
[2020-05-23 22:54:57 +0800] [13077] [INFO] Using worker: sync
[2020-05-23 22:54:57 +0800] [13084] [INFO] Booting worker with pid: 13084

```
这里最后一行是没有光标的，你没法执行其他命令，除非用<kbd>Ctrl</kbd>+<kbd>C</kbd>退出进程。这时假如你关闭终端、关闭SSH连接客户端(PuTTy, Xshell之类)，Web服务进程就立刻退出了，那不是白忙活了吗？这是因为你在终端中运行的所有进程，父进程都是当前终端会话，并且绑定了标准输入输出。很多人知道可以在命令末尾加上`&`把进程转为后台运行，但这样的后台进程并没有改变它的父进程，所以终端会话结束以后这个进程依然会不在。那么如何解决这个问题呢？我下面提供了三种解决方法，推荐程度也逐次提高。如果懒，就直接看第三种方案。

在后续介绍三种方案时，假定你运行服务器的命令是

```console
$ gunicorn -b :8888 -w 4 my_blog.wsgi
```
请根据个人情况做相应改动，**教程并不是用来百分百复制粘贴的**。如果是在虚拟环境中运行，只需要将虚拟环境的路径加到前面即可：

```console
$ /path/to/my/venv/bin/gunicorn -b :8888 -w 4 my_blog.wsgi
```
## nohup

nohup命令可以将进程变成不挂起的，（默认情况下）它会把标准输出和标准错误输入重定向到当前目录的`nohup.txt`文件中，并且将进程的父进程改成1，也就是1号进程，这样终端退出以后，此进程将继续持续运行，我们将这种进程叫做**守护进程**[^1]。使用方法如下：

```console
$ nohup gunicorn -b :8888 -w 4 my_blog.wsgi &
```
注意前面加上了`nohup`以及末尾的`&`

[^1]: 关于`nohup`命令的作用和守护进程的定义本文只做粗浅介绍，只为提供解决的方法。如果对原理作用不清楚，推荐阅读[laixintao的这篇博文](https://www.kawabangga.com/posts/3849)和[nohup,setsid与disown的不同之处](http://blog.lujun9972.win/blog/2018/04/20/nohup,setsid与disown的不同之处/index.html)

## supervisor

用`nohup`虽然能将进程转为后台运行，但它缺少一个很重要的功能：异常重启和开机自启动的功能。你重启服务器必须得记得去启动下你的服务器。所以更强大的、专门的进程管理工具就应运而生。[supervisor](http://supervisord.org/)是用Python写的一款进程管理器，它支持进程异常重启、日志存储，并且提供了一个命令行程序来查看、管理当前的进程。使用方法如下：

1. 安装
    ```console
    $ pip install supervisor
    ```
2. 生成配置文件
    ```console
    $ echo_supervisord_conf > /etc/supervisord.conf
    $ mkdir /etc/supervisor.d
    ```
    编辑`/etc/supervisord.conf`文件，将文件最后两行取消注释
    ```ini
    [include]
    files = supervisor.d/*.ini
    ```
3. 编写应用进程的配置`/etc/supervisor.d/my_blog.ini`，文件中`;`开头的行是注释行，如果需要该配置生效则取消注释
    ```ini
    [program:myblog]
    command=/path/to/my/venv/bin/gunicorn -b :8888 -w 4 my_blog.wsgi              ; 启动进程的命令
    ;process_name=%(program_name)s ; process_name expr (default %(program_name)s)
    ;numprocs=1                    ; number of processes copies to start (def 1)
    directory=/path/to/my_blog                ; 运行命令时先切换到此目录下
    ;umask=022                     ; umask for process (default None)
    ;priority=999                  ; the relative start priority (default 999)
    ;autostart=true                ; start at supervisord start (default: true)
    ;startsecs=1                   ; # of secs prog must stay up to be running (def. 1)
    ;startretries=3                ; max # of serial start failures when starting (default 3)
    ;autorestart=unexpected        ; when to restart if exited after running (def: unexpected)
    ;exitcodes=0,2                 ; 'expected' exit codes used with autorestart (default 0,2)
    ;stopsignal=QUIT               ; signal used to kill process (default TERM)
    ;stopwaitsecs=10               ; max num secs to wait b4 SIGKILL (default 10)
    ;stopasgroup=false             ; send stop signal to the UNIX process group (default false)
    ;killasgroup=false             ; SIGKILL the UNIX process group (def false)
    ;user=myuser                   ; 启动进程的用户，推荐不要用root用户，否则注释此行
    redirect_stderr=true          ; 重定向错误到输出 (默认false)
    stdout_logfile=/a/path        ; 标准输出的日志地址，会将所有print到终端的输出输出到指定的文件中
    ;stdout_logfile_maxbytes=1MB   ; max # logfile bytes b4 rotation (default 50MB)
    ;stdout_logfile_backups=10     ; # of stdout logfile backups (0 means none, default 10)
    ;stdout_capture_maxbytes=1MB   ; number of bytes in 'capturemode' (default 0)
    ;stdout_events_enabled=false   ; emit events on stdout writes (default false)
    ;stderr_logfile=/a/path        ; stderr log path, NONE for none; default AUTO
    ;stderr_logfile_maxbytes=1MB   ; max # logfile bytes b4 rotation (default 50MB)
    ;stderr_logfile_backups=10     ; # of stderr logfile backups (0 means none, default 10)
    ;stderr_capture_maxbytes=1MB   ; number of bytes in 'capturemode' (default 0)
    ;stderr_events_enabled=false   ; emit events on stderr writes (default false)
    ;environment=A="1",B="2"       ; process environment additions (def no adds)
    ;serverurl=AUTO                ; override serverurl computation (childutils)
    ```
4. 启动`supervisord`:
    ```console
    $ supervisord
    ```
5. 进程的查看、终止与启动
    ```console
    $ supervisorctl status    # 查看进程状态
    $ supervisorctl stop my_blog    # 终止my_blog进程
    $ supervisorctl start my_blog    # 启动my_blog进程
    $ supervisorctl restart my_blog    # 重新启动my_blog进程
    ```
## systemd

systemd是现在比较新的Linux发行版都自带的一个进程管理器[^2]，使用自带的，就不用再费劲安装别的库了，干净又快捷，强力推荐用这个方法。使用方法也很简单，创建以下文件内容
```ini
[Unit] 
Description=My blog service

[Service] 
Type=forking 
ExecStart=gunicorn -b :8888 -w 4 my_blog.wsgi
KillMode=process 
Restart=on-failure 
RestartSec=3s

[Install] 
WantedBy=multi-user.target
```
保存到`/etc/systemd/system/my_blog.service`。然后执行：
```console
$ systemctl enable my_blog
```
这样你的进程就自动加入开机自启动了，同样，systemd也可以查看、启动、停止进程：
```console
$ systemctl status my_blog    # 查看进程状态
$ systemctl stop my_blog    # 终止my_blog进程
$ systemctl start my_blog    # 启动my_blog进程
$ systemctl restart my_blog    # 重新启动my_blog进程
```
就是这么Easy!

[^2]: 使用`systemctl`检查下你的系统有没有安装，如果没有，则先尝试用系统的包管理工具安装`systemd`，否则就只能用`supervisor`了。