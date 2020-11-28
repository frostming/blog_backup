---
category: 编程
date: 2019-01-04 02:50:01.969142
description: ''
image: //static.frostming.com/images/2019-01-poetry.png
tags:
- Python
- Packaging
template: post
title: A deeper look into Pipenv and Poetry
---

It is 8 months passed since I posted the [article comparing Pipenv with Poetry](https://frostming.com/2018/05-15/pipenv-vs-poetry), which is the most popular article in my blog now. However, it was not a good review of the two tools, I have not even read the documentation of Poetry. In the end of last year I became a collaborator of Pipenv and util then have I realized there are so many trade-offs and, well, defects in Pipenv. In the area of software engineering, the successor always wins. The creator can't anticipate all corner cases in his prototype or original thoughts, especially for such a CLI tool that are run on millions of computers with totally different environment setup.

## Main problems with Pipenv

* Introduced more files of a new format, which is not perfect also. See how many miscellaneous files there are under the project root:
   ![](//static.frostming.com/images/2019-01-pipenv-files.png)
*  The commands and options are always [confusing and unclear](https://github.com/pypa/pipenv/issues/3316#issuecomment-442288953), and the options are not fully tested to ensure the availability.
*  Locking performance, there are [many issues](https://github.com/pypa/pipenv/issues?q=is%3Aissue+is%3Aopen+label%3A%22dependency+resolution%22) about dependency resolution. The rollment of [passa](https://github.com/sarugaku/passa) may bring a big improvement, but the timeline is still not decided yet.
*  Regression issues burned out users' patience. The test coverage is still very low, though testing against cross-platform and multi environment is a difficult and complicated mission.
*  The maintainers are maintaining a large amount of projects backing Pipenv which need to be updated at a fairly high frequency. And it in turn brings high risk of regression. All [PEEPs](https://github.com/pypa/pipenv/blob/master/peeps/PEEP-000.md)(Pipenv's enhancement proposals) need BDFL's approval while Kenneth Reitz is bothered by mental healthy and takes the back seat for a long time.

I myself are using Pipenv in daily work and help maintain Pipenv, too. So I wish a better future for Pipenv.

## What about Poetry

Poetry seems a better choice ya? I am also considering transfering to Poetry, but before that, I have to point out some downsides of it.

* Poetry doesn't work well with PyPA's current packaging system. It is very common that people clone a VCS repository and work on it. However, you can't pip install a Poetry project without extra steps to generate a `setup.py` from `pyproject.toml`.
* It is weird that Poetry puts python requires in dependency section. Python requires should be placed in global settings, although it shares the same version specifiers with normal dependencies.
* Neither Pipenv or Poetry supports to activate a virtualenv outside of project directory. I know it is inspired by NPM but in Python world people are likely to put some scripts in places other than the project directory. It is supported by virtualenvwrapper.
* Poetry only works under *one* workflow. For example, it doesn't support installing current dependencies into system Python, which is the typical workflow for developing in docker.

## What I expect in the future of Python packaging

I like the idea of ["Every project is a package"](https://poetry.eustace.io/docs/libraries/#every-project-is-a-package) and the introduction of `pyproject.toml`. It is introduced in [PEP-508](https://www.python.org/dev/peps/pep-0518/) but it is not finalized yet.

After PEP-508 is finalized, it is better that there is an official way to define dependencies in `pyproject.toml`, not in section like `tool.poetry`. It may look like:

```toml
[project]
name = "poetry"
version = "0.12.10"
description = "Python dependency management and packaging made easy."
authors = [
    "Sébastien Eustace <sebastien@eustace.io>"
]
license = "MIT"
readme = "README.md"
python = "~2.7 || ^3.4"
homepage = "https://poetry.eustace.io/"
repository = "https://github.com/sdispater/poetry"
documentation = "https://poetry.eustace.io/docs"

keywords = ["packaging", "dependency", "poetry"]

classifiers = [
    "Topic :: Software Development :: Build Tools",
    "Topic :: Software Development :: Libraries :: Python Modules"
]

# Requirements
[dependencies]
cleo = "^0.6.7"
requests = "^2.18"
cachy = "^0.2"
requests-toolbelt = "^0.8.0"
jsonschema = "^3.0a3"
pyrsistent = "^0.14.2"
pyparsing = "^2.2"
cachecontrol = { version = "^0.12.4", extras = ["filecache"] }
pkginfo = "^1.4"
html5lib = "^1.0"
shellingham = "^1.1"
tomlkit = "^0.5.1"

# The typing module is not in the stdlib in Python 2.7 and 3.4
typing = { version = "^3.6", python = "~2.7 || ~3.4" }

# Use pathlib2 for Python 2.7 and 3.4
pathlib2 = { version = "^2.3", python = "~2.7 || ~3.4" }
# Use virtualenv for Python 2.7 since venv does not exist
virtualenv = { version = "^16.0", python = "~2.7" }
# functools32 is needed for Python 2.7
functools32 = { version = "^3.2.3", python = "~2.7" }

[dev-dependencies]
pytest = "^3.4"
pytest-cov = "^2.5"
mkdocs = { version = "^1.0", python = "~2.7.9 || ^3.4" }
pymdown-extensions = "^6.0"
pygments = "^2.2"
pytest-mock = "^1.9"
pygments-github-lexers = "^0.0.5"
black = { version = "^18.3-alpha.0", python = "^3.6" }
pre-commit = "^1.10"
tox = "^3.0"
pytest-sugar = "^0.9.2"

[scripts]
poetry = "poetry.console:main"

```

I hope `pyproject.toml` will eventually replace `setup.py`, and in the transition period, Pip, or whatever name, should be able to read both files. The "Pip" should be a combination of Pipenv and Poetry and be the ultimate solution for Python packaging.

* * *
## Update

Another drawbacks I found recently: Pipenv, or more precisely, virtualenv, doens't use the built-in venv module to create a VE, which may bring troubles:

* When the Python interpreter is updated, the VE will become stale.
* Some packages such as `matplotlib` requires framework build on macOS. Virtualenv creates non-framework build even if the original one is framework-build

I [forked the virtualenv](https://github.com/frostming/virtualenv-venv) with a patch to address these problems. Replace the PyPI virtualenv via:

```bash
$ pip install -I https://github.com/frostming/virtualenv-venv/releases/download/16.2.0-fork/virtualenv-16.2.0_fork-py2.py3-none-any.whl
```

Everything works well now.