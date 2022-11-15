English | [中文](README_ZH.md)

# circuit-breaker

## Overview

`circuit-breaker` is triggered by detecting an abnormal status code (e.g. 5xx) and restored to a healthy state by detecting a successful status code (e.g. 2xx)

`circuit-breaker` inspired by `apisix`.

## License

Source code of `circuit-breaker` should be distributed under the Apache-2.0 license.

## Acknowledgments

* [apisix](https://github.com/apache/apisix/blob/master/apisix/plugins/api-breaker.lua)