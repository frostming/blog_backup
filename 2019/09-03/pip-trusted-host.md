---
category: 编程
date: 2019-09-03 05:28:35.983371
description: ''
image: https://files.realpython.com/media/What-is-PIP_Watermarked.c46f49dc33f9.jpg
tags:
- Python
template: post
title: Pip trusted_host问题记录
---

## 问题定位

一日我在Pipenv上收到一个[issue](https://github.com/pypa/pipenv/issues/3841): 用户说Pipenv执行的pip命令中`--trusted-host`缺少了port部分。然后我去扒源码，结果发现有两处同样的函数：[[1]](https://github.com/pypa/pipenv/blob/3b9b7172293169ad5ce0b7be77e6f27e3dbcde7b/pipenv/utils.py#L266)[[2]](
https://github.com/pypa/pipenv/blob/3b9b7172293169ad5ce0b7be77e6f27e3dbcde7b/pipenv/vendor/requirementslib/utils.py#L283)逻辑不一致。顿时感觉事情没那么简单。于是我本地搞了一个pypi server, 并用自签名支持了https，然后用pip测试[^1]：

```bash
$ pip install -i https://localtest.me:5001 urllib3 --trusted-host localtest.me:5001
Successful

$ pip install -i https://localtest.me:5001 urllib3 --trusted-host localtest.me
Looking in indexes: https://localtest.me:5001
Collecting urllib3
  Retrying (Retry(total=4, connect=None, read=None, redirect=None, status=None)) after connection broken by 'SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1076)'))': /urllib3/
  ...
  Failed

$ pip install -i http://localtest.me:5000 urllib3 --trusted-host localtest.me:5000
Looking in indexes: http://localtest.me:5000
Collecting urllib3
  The repository located at localtest.me is not a trusted or secure host and is being ignored. If this repository is available via HTTPS we recommend you use HTTPS instead, otherwise you may silence this warning and allow it anyway with '--trusted-host localtest.me'.
  Could not find a version that satisfies the requirement urllib3 (from versions: )
No matching distribution found for urllib3

$ pip install -i http://localtest.me:5000 urllib3 --trusted-host localtest.me
Successful
```

惊呆，HTTPS和HTTP针对`trusted-host`带不带port的处理方式不一样：HTTPS希望你带port，而HTTP不需要带port。这显然是不合理的，于是我去看pip的源码关于这块的处理逻辑。以下基于pip 19.2.3的源码。
`src/pip/_internal/download.py`

```python
...
    insecure_adapter = InsecureHTTPAdapter(max_retries=retries)
    # Save this for later use in add_insecure_host().
    self._insecure_adapter = insecure_adapter

    self.mount("https://", secure_adapter)
    self.mount("http://", insecure_adapter)

    # Enable file:// urls
    self.mount("file://", LocalFSAdapter())

    # We want to use a non-validating adapter for any requests which are
    # deemed insecure.
    for host in insecure_hosts:
        self.add_insecure_host(host)

def add_insecure_host(self, host):
    # type: (str) -> None
    self.mount('https://{}/'.format(host), self._insecure_adapter)
```
`insecure_adapter`是不检查证书的，`secure_adapter`是检查证书的，可以看到在`add_insecure_host()`这个函数中，是把传进来的host加上末尾的`/`拼成一个URL来新增一个adapter端点的，而在requests中，多个adapter端点是依靠`startswith`来识别是否匹配的。所以如果`trusted-host`是`example.org`，则只有`https://example.org/`会被识别为信任的站点而`https://example.org:8080/`不会。

以上是仅针对HTTPS而言，HTTP是无需证书检查的，它相关的逻辑在

`src/pip/_internal/index.py`

```python
def _validate_secure_origin(self, logger, location):
    # type: (Logger, Link) -> bool
    # Determine if this url used a secure transport mechanism
    parsed = urllib_parse.urlparse(str(location))
    origin = (parsed.scheme, parsed.hostname, parsed.port)

    # The protocol to use to see if the protocol matches.
    # Don't count the repository type as part of the protocol: in
    # cases such as "git+ssh", only use "ssh". (I.e., Only verify against
    # the last scheme.)
    protocol = origin[0].rsplit('+', 1)[-1]

    # Determine if our origin is a secure origin by looking through our
    # hardcoded list of secure origins, as well as any additional ones
    # configured on this PackageFinder instance.
    for secure_origin in self.iter_secure_origins():
        if protocol != secure_origin[0] and secure_origin[0] != "*":
            continue

        try:
            # We need to do this decode dance to ensure that we have a
            # unicode object, even on Python 2.x.
            addr = ipaddress.ip_address(
                origin[1]
                if (
                    isinstance(origin[1], six.text_type) or
                    origin[1] is None
                )
                else origin[1].decode("utf8")
            )
            network = ipaddress.ip_network(
                secure_origin[1]
                if isinstance(secure_origin[1], six.text_type)
                # setting secure_origin[1] to proper Union[bytes, str]
                # creates problems in other places
                else secure_origin[1].decode("utf8")  # type: ignore
            )
        except ValueError:
            # We don't have both a valid address or a valid network, so
            # we'll check this origin against hostnames.
            if (origin[1] and
                    origin[1].lower() != secure_origin[1].lower() and
                    secure_origin[1] != "*"):
                continue
        else:
            # We have a valid address and network, so see if the address
            # is contained within the network.
            if addr not in network:
                continue

        # Check to see if the port patches
        if (origin[2] != secure_origin[2] and
                secure_origin[2] != "*" and
                secure_origin[2] is not None):
            continue

        # If we've gotten here, then this origin matches the current
        # secure origin and we should return True
        return True

    # If we've gotten to this point, then the origin isn't secure and we
    # will not accept it as a valid location to search. We will however
    # log a warning that we are ignoring it.
    logger.warning(
        "The repository located at %s is not a trusted or secure host and "
        "is being ignored. If this repository is available via HTTPS we "
        "recommend you use HTTPS instead, otherwise you may silence "
        "this warning and allow it anyway with '--trusted-host %s'.",
        parsed.hostname,
        parsed.hostname,
    )

    return False
```
看上去是分别匹配scheme, hostname和port，没什么问题。问题在于`self.iter_secure_origins()`这里产生的值，在同一个文件中：
```python
def iter_secure_origins(self):
    # type: () -> Iterator[SecureOrigin]
    for secure_origin in SECURE_ORIGINS:
        yield secure_origin
    for host in self.trusted_hosts:
        yield ('*', host, '*')
 ```
 这里没做任何处理，就把`trusted-host`当做hostname丢出来了，看来这里压根没考虑过`trusted-host`带port的需求。
 
 ## 问题修复
 
 找到了问题所在，总结一下：
 
 * HTTPS需要带port是因为`requests.Session`的`mount`是依靠前缀匹配来获取对应的适配器（adapter）的，并且末尾会加上一个`/`。
 * HTTP需要不带port是因为检查是否安全URL的时候，是拿目标URL的hostname（不带port）去匹配`trusted-host`的值。

所以对应的修复方法就是：

* 添加信任的端点时，如果`trusted-host`不带port，则需要把`https://hostname:`也添加为无需安全检查的端点（利用前缀匹配的特性）。
* 生成`secure_origin`时解析传入的`trusted-host`值，分成hostname与port部分分别匹配。

具体代码可以看[我提交的PR](https://github.com/pypa/pip/pull/6909)，这个PR已经被merge，预计可以在下个版本中发布。

[^1]: 这里我用了一个trick，使用了[localtest.me](http://localtest.me)转发localhost的请求，因为localhost是永远被信任的地址，trusted-host不起作用。