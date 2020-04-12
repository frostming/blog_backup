---
author: Frost Ming
category: 编程
date: 2020-04-12 04:29:14.356700
description: PDM 实现 PEP 582 遇到的坑
image: ''
tags:
- 日志
- Python
title: PEP 582的开发日志
---

[PEP 582](https://www.python.org/dev/peps/pep-0582/) 是Python的一个隔离项目环境的提案。PDM作为现有的唯一一个具有完备PEP 582支持的包管理器，在实现的过程中也并非一帆风顺。本文将介绍一些关键PEP 582特性的实现方法和历程。
<!--more-->