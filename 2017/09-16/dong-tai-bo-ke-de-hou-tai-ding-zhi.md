---
category: 编程
date: 2017-09-16 13:12:09
description: 自定义 Flask-Admin 的表单控件
image: //static.frostming.com/images/cea81519240203f5f41bc8e1e6b512db.png
tags:
- Web
- 博客
- Flask
template: post
title: 动态博客的后台定制
---

[![](https://badge.juejin.im/entry/59bfd19a5188256c4b72456a/likes.svg?style=flat)](https://juejin.im/entry/59bfd19a5188256c4b72456a/detail)

搭建动态博客的初衷就是想随时随地，只要一个浏览器，就能更新博客。那么就需要一个后台来管理文章，包含文章编辑器，和各种表单控件。

## 编辑器

先来解决文本编辑器的问题，CKEditor 功能强大，但只是一个富文本编辑器。对于已经习惯 Markdown 写作的我来说，只管写，排版渲染就交给浏览器去做。找了很多内嵌 Markdown 编辑器，既要外观匹配，还要最好带预览功能。最终我选择了 [Simple MDE](https://simplemde.com/)。

使用方法非常简单，引入 CSS, Javascript 文件后，只需要一句话就搞定了：

```html
<script>
var simplemde = new SimpleMDE({ element: document.getElementById("MyID") });
</script>
```

具体到 Flask-Admin，只需重载`admin/model/edit.html`和`admin/model/create.html`模板文件，在其中加入对应 HTML 代码，然后在`ModelView`中分别指定`create_template`和`edit_template`就行了。外观如下：

![](//static.frostming.com/images/f6aca0a2dcd505bec32431b8def9980c.png) ![](//static.frostming.com/images/1e68d9b76e35928fcf4e833ecd3e7786.png)

我已经事先把 Flask-Admin 的基模板给换成了 bootstrap4。这个编辑器全屏模式下支持分栏预览，非常惊艳。

## Tag 与 Category 输入框

`Tag`与`Category`是`Post`的两个属性，其中一个是多对多关系，另一个是一对多关系。Flask-Admin 原生支持这两种类型的属性输入框，但有以下不足：

- 基于 Select2 3.x，不支持自由输入的选择框（tags）。
- 无法动态添加不存在的项到数据库中。

针对以上两点开始我们的定制。首先将要加载自由输入的选择框打上 HTML 标记，在`ModelView`中：

```python
form_widget_args = {
    'tags': {'data-role': 'select2-free'},
    'category': {'data-role': 'select2-free'},
}
```

重载`edit.html`和`create.html`，引入 select2 4.0.x 的文件，以及以下 Javascript 代码：

```html
$('[data-role=select2-free]').each(function(){
      $(this).select2({tags: true});
    });
```

现在可以自由输入了，还需要动态添加。查看 Flask-Admin 的源码，对应这两种域的表单分别定义为`QuerySelectField`与`QuerySelectMultiField`，它们被 hardcode在`AdminModelConverter._model_select_field`里面，而`AdminModelConverter`在`ModelView`中被指定。所以我们要重载`QuerySelectField`的行为，则需要继承`AdminModelConverter`，重载下面的`_model_select_field`方法，再将其加载到我们自定义的`ModelView`就可以了，示意图如下：

![](//static.frostming.com/images/d82620114808d9527afacfda0d2e3b17.png)

为了自定一个`SelectField`，重载了三个类，真是大费周章。在重载的`QuerySelectField`里，我们需要实现以下逻辑：

- 先寻找匹配的 model 对象，并绑定到`form.data`里（未重载之前的行为）
- 剩下的未匹配的选择项，为它们创建 model 对象，并绑定到`form.data`里。

```python
class AutoAddSelectField(QuerySelectField):
    def __init__(self, model_factory, *args, **kwargs):
        super(AutoAddSelectField, self).__init__(*args, **kwargs)
        self.model_factory = model_factory

    def _get_data(self):
        if self._formdata is not None:
            for pk, obj in self._get_object_list():
                if pk == self._formdata:
                    self._set_data(obj)
                    break
            else:
                obj = self.model_factory(self._formdata)
                self._set_data(obj)
        return self._data

    def _set_data(self, data):
        self._data = data
        self._formdata = None

    data = property(_get_data, _set_data)

    def pre_validate(self, form):
        pass
```
我们要在初始化时传入 model 的创建方法，并取消了有效性检查。`QuerySelectMultiField`也大同小异了。最终效果如下：

![](//static.frostming.com/images/Untitled.gif)

## 美中不足

动态添加做好了，那么删除呢？想像一下这个使用场景，你修改文章，把一个标签删除了，这个标签已经没有任何文章使用，那你肯定不希望它再出现在标签列表里吧？SQLAlchemy 中有`cascade`属性，用来指定`parent`改变时`child`的行为，但不符合我们的要求，因为我们要的是一对多和多对多关系中「多」的一方变化时另一方的行为。于是我们需要监听`before_flush`信号，检查当前`session`中的对象并做对应处理。

```python
def auto_delete_orphans(attr):
    target_class = attr.parent.class_

    @sa.event.listens_for(sa.orm.Session, 'after_flush')
    def delete_orphan_listener(session, ctx):
        session.query(target_class).filter(~attr.any())\
                                   .delete(synchronize_session=False)

auto_delete_orphans(Tag.posts)
auto_delete_orphans(Category.posts)
```
