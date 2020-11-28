---
category: 编程
date: 2018-05-15 03:24:36.869245
description: ''
image: https://us.pycon.org/2018/site_media/static/img/pycon2018.f76001445fbb.png
tags:
- Python
- Packaging
template: post
title: 'Python packaging war: Pipenv vs. Poetry'
---

This is my second post about Python packaging. In the [last post](/2017/11-19/python-packaging), I regarded **npm** as my ideal packaging management tool because I had limited experience about other tools in other languages. Honestly saying, **npm** is never perfect with many drawbacks in its own, but it also has many things we can learn from.

**Pipenv**, brought to the community again by [Kenneth Reitz] on [PyCon 2018], which is also mentioned in the last post, is more than 1 year old since it was born. In the past months I have becomed a contributor of the project, during which time I gained more understanding of its philosophy and design purpose. As explained [here], **Pipenv** is designed for application deps management, rather than libraries. You still have to maintain a `setup.py` file besides `Pipfile` to serve as a library configuration file. From my daily experience of using this amazing project, it handles all the messing stuff of virtualenvs and installation, which saves lots of lines in `README.md`, but it's far from perfect regarding the issue number in its issue tracker.

[Kenneth Reitz]: https://kennethreitz.org
[PyCon 2018]: https://www.youtube.com/watch?v=GBQAKldqgZs&feature=youtu.be
[here]: https://docs.pipenv.org/advanced/#pipfile-vs-setuppy

Then I encountered a much younger project -- **Poetry**, which is only 3 months old with less than 600 starts on [GitHub repo](https://github.com/sdispater/poetry)(compare to 11000+ stars of **Pipenv**). **Poetry** uses [standardized](https://www.python.org/dev/peps/pep-0518/) `pyproject.toml` instead of customized `Pipfile` as the project deps configuration file. It's more like a `packaging.json` as in Javascript's packaging world in following ways:

1. It can serve for both applications and libraries, depending on whether you do *upload* or not.
2. Packages are prefered to be installed with non-wildcard version, with support of [multiple version specifiers](https://poetry.eustace.io/docs/versions/)

**Poetry** does a lot of work on deps resolution and packaging, so that `pyproject.toml` can **replace** `setup.py`, it is monolithic. While **Pipenv** is more like a wrapper built on top of pip and virtualenv(or pew). Kenneth Reitz is very good at adopting amazing tools and merge them together to be a project really powerful and easy to use(same as [requests-html](https://pypi.org/p/requests-html)), but SDispater, with his **Poetry**, in my honest opinion, is making Python packaging much different.

I am not putting down any one and raising the other, but the current status is that **Pipenv** is more exposed to the community with KR's fame and great talks, and it's also adopted by PyPA. But PyPA is never an authority though the word is in its name, and standard may change. For the long time of view, let the large community choose the winner, but before it's finalized, there must be a [war](https://www.reddit.com/r/Python/comments/8jd6aq/why_is_pipenv_the_recommended_packaging_tool_by/) between these two tools.

<div class="alert alert-info">

#### Update

This post was written without an intensive review of the two tools and was likely to be biased. After having been the maintainer of Pipenv for months, I wrote a [new post](/2019/01-04/pipenv-poetry) with a deeper look into these tools.
</div>