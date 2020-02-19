---
author: null
category: 编程
date: 2017-03-30 20:13:46
description: null
image: null
tags:
- Web
- Python
- SQLite
title: SQLite 爬坑记
---

作为从零开始的Web开发人员，在项目开发中总是遇到这样那样的坑，其中数据库的坑最多。由于在功能完善过程中需要变换频繁，不可避免地要更改DB Schema，不过我都是能不改尽量不改。逃不过时，只能硬着头皮刚。

故事是这样的，我要把两个表中的某两列的类型由字符型改成列表。在数据库值类型中就是BLOB，ORM中叫做PickleType。数据库使用SQLite，ORM使用SQLAlchemy，并使用基于Alembic的自动化迁移工具，于是就开始了。
<!--more-->
## Round 1
直接开搞

migrate。。。咦？怎么脚本没生成？Google之，Alembic不能探测类型变化。

OK，我手动写个好了吧，upgrade。。。报错！ALTER TABLE 不支持改变类型。

## Round 2
好在这两列也是新加不久，并不十分重要，于是我想到了，我删了再加可以了吧？

downgrade。。。报错！drop column也不支持。

## Round 3
看来只能放弃自动化迁移了，Google一番，找到一个drop column的workaround:复制一个去掉该列的新表，并覆盖原表。

```
create table temp as select col1,col2... from old_table;
drop table old_table;
alter table temp rename to old_table;
```
这时候再migrate，正确生成了脚本：
```
add_column ......
add_column ......
create_foreign_key ...
```
嗯。。看上去不错，最后一行是。。新表没有带上外键信息。

upgrade。。。报错！create_foreign_key失败！SQLite也不支持，无语了，不愧是Lite，怎么不去屎？

进数据库看看，新的列已经加上了，查了一下已有的关联列，没啥问题啊？

LEAVE IT ALONE!管它了，跑起来，新增一行数据，Beng shaka laka！原来缺少外键信息已有数据没问题，新增就出问题，还加了一行死数据，删不掉还（没有生成主键）。

## Round 4
从备份恢复数据库。Google外键问题，得到答案是别无他法，只能重新建表再复制数据。
```
alter table old_table rename to temp;
create table old_table (...);
insert into old_table select col1,col2,... from temp;
drop table temp;
```
重新建立migration文件夹，运行测试，一切正常。

## 总结：
备份备份备份，折腾数据库之前一定要备份！不然就等着哭吧。代码用版本控制管理，数据库备份，我才有底气胡搞一通。

特别感谢Google以及StackOverflow提供的帮助。

珍爱生命，请用MySQL。
