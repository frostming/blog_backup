---
category: 编程
date: 2018-09-11 03:56:26.809331
description: Flask博客部署到云服务器完整流程
image: //static.frostming.com/images/2018-09-blog-t.jpg
tags:
- 博客
- Python3
- Flask
template: post
title: Flask+Nginx博客容器化部署
---

> **2019.03.05更新内容**
> 0x08 HTTPS
> 
> **2019.08.09更新内容**
> 使用构建好的Docker镜像
> 
> **2019.12.04更新内容**
> 更新.env配置内容
> 
> **2020.05.19更新内容**
> 简化部署步骤

我是一个爱折腾的人，2016年才开始学会自建博客，到现在博文没写多少篇却折腾了好几回。经历了Hexo+GitHub Page，再到Flask+Heroku，现在终于用上了国内云服务+Nginx，感觉速度快了很多。总结起来，使用Flask+Nginx，好处有以下几个方面：

* 可DIY程度高，现在我用的自己开发的Markdown引擎，非常方便扩展，在此推荐一下：[Marko](https://github.com/frostming/marko)
* 依靠Nginx强大的反向代理，现在我终于不用到处存图片然后贴一个巨长的URL了，直接映射到`/images/`下，干净整洁。
* HTTPS支持，可以用云服务购买的免费证书，也可以用Letsencrypt，甚至可以用自签名证书。

我之前部署Flask的网站一直都用的virtualenv，现在既然切到云服务器，就干脆换成用Docker了，隔离化程度更高，我也可以用现在最新版本的Python了。博客系统可拆分为三个部分：
* Flask应用，负责处理请求，是系统的核心
* 数据库
* Nginx服务器

三个部分分别独立为一个容器。从一个全新的云服务器开始（以Ubuntu Server 16.04.1为例，其余系统类似），部署步骤如下：

## 0x00 添加用户

使用一个非root的用户是一个好习惯，需要自己添加：

```console
# adduser fming
# echo "fming   ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
```
然后切换到fming用户登录

## 0x01 安装Docker

```console
$ curl -fsSL https://get.docker.com -o get-docker.sh
$ sudo sh get-docker.sh
```
此脚本将自动将Docker CE安装到系统上，若安装失败，可尝试[其他安装方法](https://docs.docker.com/install/linux/docker-ce/ubuntu/#install-docker-ce)。安装完成后，需添加当前用户到docker组：
```console
$ sudo usermod -aG docker $USER
```
## 0x02 安装Docker-compose
Docker-compose是一款Docker的工具，它能让你高效管理多个容器，否则需要加一大堆选项到Docker命令后。它同样提供了一个一键安装脚本（[其他安装方法](https://docs.docker.com/compose/install/#install-compose)）：
```console
$ sudo curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```

## 0x03 创建本地环境配置

在代码根目录下（与`docker-compose.yml`同级）创建`.env`文件，主要是数据库相关的环境变量，请自行填写缺失变量：
```
SECRET_KEY=<服务器密钥>
FLASK_APP=flaskblog.app
FLASK_MAIL_USERNAME=<发送邮件使用的用户名>
FLASK_MAIL_SERVER=<发送邮件的SMTP/IMAP地址>
FLASK_MAIL_PASSWORD=<发送邮件的密码>
FLASK_MAIL_SENDER=<显示名称 <邮箱地址>>

GITHUB_CLIENT_ID=<GitHub OAuth2 Client ID>
GITHUB_CLIENT_SECRET=<GitHub OAuth2 Client Secret>
GOOGLE_CLIENT_ID=<Google OAuth2 Client ID>
GOOGLE_CLIENT_SECRET=<Google OAuth2 Client Secret>
POSTGRES_USER=xxx
POSTGRES_PASSWORD=xxx
POSTGRES_DB=flog_db
DB_SERVICE=db
DATABASE_URL=postgresql+psycopg2://xxx:xxx@db:5432/flog_db
CERTBOT_EMAIL=<Your Email Address>
```
使用`db`就可以指代数据库容器的服务地址了。

*注意：`.env`和`./nginx/cert`（证书目录）不可提交到版本控制平台上。*

## 0x04 构建静态文件

博客的后台部分用到了Vue.js + ElementUI，需要构建静态文件，使用起来也很简单：

```console
$ cd static
$ npm i
$ npm run build:prod
```

## 0x05 Nginx配置
在上一节的配置中可以看到我把Nginx的配置文件映射到了`./nginx/conf.d/default.conf`中。编辑该文件，修改`servername`为你的域名，ssl开头的部分暂时不变，我们会在后面修改它。配置的一些说明：

### 主站
```Nginx
location / {
	proxy_pass http://web:5000;
	proxy_set_header Host $host;
	proxy_set_header X-Real-IP $remote_addr;
	proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
}
```
### 配置静态文件缓存
```Nginx
proxy_temp_path /tmp/temp_dir;
proxy_cache_path /tmp/cache levels=1:2 keys_zone=mycache:100m inactive=1d max_size=10g;
server {
...
location /static {
	alias /opt/static;
	proxy_set_header Host $host;
	proxy_cache mycache;
	expires 30d;
}
```
我之前已经把静态文件映射到Nginx容器中的`/opt/static`了。

## 0x06 启动容器

好了，万事俱备，现在可以启动容器了！转到仓库所在目录：
```console
$ docker-compose up --build -d
```
拉取镜像，构建镜像，启动容器，一条命令足矣！一切都没有问题的话，你的网站已经跑起来了。

请参考此[博客的GitHub](https://github.com/frostming/Flog)获取完整配置。

现在，你的博客已经启用HTTPS了，地址栏前面会出现一个锁标志，可以到[Qualys SSL Labs](https://www.ssllabs.com/ssltest/index.html)检测你的网站安全分数。
![我的是A+](//static.frostming.com/images/2019-03-ssl-score.png "我的是A+")

更多阅读：[LET'S ENCRYPT 给网站加 HTTPS 完全指南](https://ksmx.me/letsencrypt-ssl-https/)

## 0x07 初始化博客

第一次启动博客，请先到 `<your domain>/admin/#/settings`设置你的博客。
