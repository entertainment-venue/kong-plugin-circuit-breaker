[英文](README.md) | 中文

# circuit-breaker

## 简介

`circuit-breaker`通过探测异常状态码（比如 5xx）来触发熔断，首次探测失败熔断2秒，2s后继续探测失败熔断4s，以此类推直至配置上限。

`circuit-breaker`通过探测成功状态码（比如 2xx）来恢复健康状态。

`circuit-breaker`灵感源于`apisix`。

## 证书

`kong-plugin-circuit-breaker` 的源码需在遵循 Apache-2.0 开源证书的前提下使用。

## 鸣谢

- 感谢[apisix](https://github.com/apache/apisix/blob/master/apisix/plugins/api-breaker.lua)。