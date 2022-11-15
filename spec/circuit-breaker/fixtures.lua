local _M = {}

_M.fixtures = {
    http_mock = {
        circuit_breaker = [[
        server {
            server_name circuit_breaker;
            listen 10000;
            charset utf-8;
            charset_types application/json;
            default_type application/json;
            location = "/foo/bar" {
                content_by_lua_block {
                    ngx.status = tonumber(ngx.req.get_headers()["response_http_code"])
                    ngx.say("success")
                    return ngx.exit(0)
                }
            }
        }
  ]]
    },
}

return _M