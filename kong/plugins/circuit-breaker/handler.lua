-- Licensed to the Apache Software Foundation (ASF) under one or more
-- contributor license agreements.  See the NOTICE file distributed with
-- this work for additional information regarding copyright ownership.
-- The ASF licenses this file to You under the Apache License, Version 2.0
-- (the "License"); you may not use this file except in compliance with
-- the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

local kong = kong
local ngx = ngx
local ipairs = ipairs
local fmt = string.format
local math_floor = math.floor
local re_find = ngx.re.find
local shared_buffer = ngx.shared.kong_circuit_breaker

local CircuitBreakerHandler = {
    VERSION = "1.0.0",
    PRIORITY = 920,
}

local function check_whitelist(conf)
    local uri = kong.request.get_path()
    if conf.whitelist then
        for _, rule in ipairs(conf.whitelist) do
            if re_find(uri, rule, "jo") then
                return true
            end
        end
    end
    return false
end

local function array_find(array, val)
    for i, v in ipairs(array) do
        if v == val then
            return i
        end
    end

    return nil
end

local function check_shared_dict()
    if not shared_buffer then
        kong.log.err("circuit_breaker: ngx shared dict 'kong_circuit_breaker' not found")
        return
    end
end

local function get_host()
    return kong.request.get_host()
end

local function get_host_path()
    local path = kong.request.get_path()
    if not path then
        path = ""
    end
    local host = get_host()
    return fmt("%s%s", host, path)
end

local function gen_healthy_key(limit_by)
    return "healthy-" .. limit_by
end

local function gen_unhealthy_key(limit_by)
    return "unhealthy-" .. limit_by
end

local function gen_lasttime_key(limit_by)
    return "unhealthy-lastime" .. limit_by
end

function CircuitBreakerHandler:init_worker()
    check_shared_dict()
end

function CircuitBreakerHandler:access(conf)
    if check_whitelist(conf) then
        kong.log.debug("hit whitelist, uri: ", kong.request.get_path())
        return
    end
    kong.ctx.plugin.is_circuit_break = false
    local limit_by = "host" == conf.limit_by and get_host() or get_host_path();
    local unhealthy_key = gen_unhealthy_key(limit_by)
    -- unhealthy counts
    local unhealthy_count, err = shared_buffer:get(unhealthy_key)
    if err then
        kong.log.warn("circuit_breaker, failed to get unhealthy_key: ", unhealthy_key, " err: ", err)
        return
    end

    if not unhealthy_count then
        return
    end

    local lasttime_key = gen_lasttime_key(limit_by)
    local lasttime, err = shared_buffer:get(lasttime_key)
    if err then
        kong.log.warn("circuit_breaker: failed to get lasttime_key: ", lasttime_key, " err: ", err)
        return
    end

    if not lasttime then
        return
    end

    local failure_times = math_floor(unhealthy_count / conf.unhealthy.failures)
    if failure_times < 1 then
        failure_times = 1
    end

    -- cannot exceed the maximum value of the user configuration
    local breaker_time = 2 ^ failure_times
    if breaker_time > conf.max_breaker_sec then
        breaker_time = conf.max_breaker_sec
    end
    kong.log.info("circuit_breaker: breaker_time: ", breaker_time)

    -- breaker
    if lasttime + breaker_time >= ngx.time() then
        kong.log.err("circuit_breaker: circuit breaker is open, unhealthy_key: ", unhealthy_key, " count: ", unhealthy_count)
        kong.ctx.plugin.is_circuit_break = true
        return kong.response.exit(conf.break_response_code, { message = "circuit breaker is open" })
    end

    return
end

function CircuitBreakerHandler:log(conf)
    if check_whitelist(conf) then
        kong.log.debug("hit whitelist, uri: ", kong.request.get_path())
        return
    end

    -- access is_circuit_break return
    if kong.ctx.plugin.is_circuit_break then
        return
    end

    local limit_by = "host" == conf.limit_by and get_host() or get_host_path();
    local unhealthy_key = gen_unhealthy_key(limit_by)
    local healthy_key = gen_healthy_key(limit_by)
    local lasttime_key = gen_lasttime_key(limit_by)
    local upstream_status = kong.response.get_status()

    if not upstream_status then
        return
    end

    -- unhealth process
    if array_find(conf.unhealthy.http_statuses, upstream_status) then
        local unhealthy_count, err = shared_buffer:incr(unhealthy_key, 1, 0)
        if err then
            kong.log.warn("circuit_breaker:failed to incr unhealthy_key: ", unhealthy_key, " err: ", err)
        end
        kong.log.notice("circuit_breaker: unhealthy_key: ", unhealthy_key, " count: ", unhealthy_count)

        shared_buffer:delete(healthy_key)

        -- whether the user-configured number of failures has been reached,
        -- and if so, the timestamp for entering the unhealthy state.
        if unhealthy_count % conf.unhealthy.failures == 0 then
            shared_buffer:set(lasttime_key, ngx.time(), conf.max_breaker_sec)
            kong.log.info("circuit_breaker: update lasttime_key: ", lasttime_key, " to ", ngx.time())
        end

        return
    end

    -- health process
    if not array_find(conf.healthy.http_statuses, upstream_status) then
        return
    end

    local unhealthy_count, err = shared_buffer:get(unhealthy_key)
    if err then
        kong.log.warn("circuit_breaker: failed to `get` unhealthy_key: ", unhealthy_key, " err: ", err)
    end

    if not unhealthy_count then
        return
    end

    local healthy_count, err = shared_buffer:incr(healthy_key, 1, 0)
    if err then
        kong.log.warn("circuit_breaker: failed to `incr` healthy_key: ", healthy_key, " err: ", err)
    end

    -- clear related status
    if healthy_count >= conf.healthy.successes then
        -- stat change to normal
        kong.log.notice("circuit_breaker: chagne to normal, healthy_key: ", healthy_key, " count: ", healthy_count)
        shared_buffer:delete(lasttime_key)
        shared_buffer:delete(unhealthy_key)
        shared_buffer:delete(healthy_key)
    end

    return
end

return CircuitBreakerHandler
