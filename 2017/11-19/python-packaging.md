---
category: 编程
date: 2017-11-19 22:25:38.869530
description: null
image: null
tags:
- Python
- Packaging
template: post
title: What's the problem about Python packaging?
---

I have been using Python as my primary programming language for 4 years. It is elegant, easy coding and reading. I didn't notice the discomfort until I came to know about [Node.js](https://nodejs.org). All you need to do to install all the dependencies is a single command `npm install`. If you want to install another library to your project, just install it  with npm, and append `--save` to save it in the config file, usually `package.json`.  There is no trouble of polluting the environment of other projects, because the install root is totally isolated unless you add `--global` explicitly.

Now when I looked into the python packaging system again I found many inconvenience and messes, as many other articles indicates[^1]. The `pip` and `setuptools` requires a `setup.py` in the project root, which is similar with `package.json`. It defines the requirements of installation together with project information. However, `pip` always install the library and all dependencies in your current python root without the help of other tools. [virtualenv](https://virtualenv.pypa.io) and its followers setup an isolated virtual environment which is done by altering the python root when activated.

[^1]: https://medium.com/@alonisser/things-i-wish-pip-learned-from-npm-f712fa26f5bc

The problem is solved, right? I don't think so, when it comes to deployment. I have been developing and running some web applications written in python web framework, Flask and Django. The deployment is quite complicated and easy to fail. Dynamic languages require an almost same runtime environment installed on the target machine. Same dependencies, same 3rd party libs, etc. Any change of requirement version may cause a failure in deployment. [Go language](https://golang.org/), which I learned recently, is another polar. It brings me brand new experiences of deployment and let me scream: "That is the way!". With statically compiled binary, all things to do in deployment is just a copy command, and it can work on any machine. But I don't like the way Go package organizes -- every modularized file locates under the same directory, which makes the hierarchy unclear.

This is what I need Python learn from node.js and go. Fortunately, [Kenneth Reitz](https://kennethreitz.org) developed a superb library for Python packaging: [Pipenv](https://docs.pipenv.org/). It is the most modern packaging tools in my opinion, which brings me almost the same experience as npm. Life is short, throw away pip, easy-install from now on and use Pipenv!