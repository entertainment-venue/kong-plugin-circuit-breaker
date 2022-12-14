local schema_def = require "kong.plugins.circuit-breaker.schema"
local v = require("spec.helpers").validate_plugin_config_schema

describe("Plugin: circuit-breaker (schema)", function()
    it("should accept a valid break_response_code", function()
        assert(v({ break_response_code = 503 }, schema_def))
    end)
    it("should accept a valid limit_by", function()
        assert(v({ limit_by = "host" }, schema_def))
    end)
    it("should accept a valid max_breaker_sec", function()
        assert(v({ max_breaker_sec = 32 }, schema_def))
    end)
    it("should accept a valid unhealthy", function()
        assert(v({ unhealthy = { failures = 3, http_statuses = { 500, 502, 503 } } }, schema_def))
    end)
    it("should accept a valid healthy", function()
        assert(v({ healthy = { successes = 3, http_statuses = { 200 } } }, schema_def))
    end)
    it("should accept a valid whitelist", function()
        assert(v({ whitelist = { "/aaa", "^/bbb$" } }, schema_def))
    end)

    describe("errors", function()
        it("break_response_code should only accept numbers", function()
            local ok, err = v({ break_response_code = "abcd" }, schema_def)
            assert.falsy(ok)
            assert.same("expected a number", err.config.break_response_code)
        end)
        it("break_response_code < 200", function()
            local ok, err = v({ break_response_code = 199 }, schema_def)
            assert.falsy(ok)
            assert.same("value should be between 200 and 599", err.config.break_response_code)
        end)
        it("break_response_code > 599", function()
            local ok, err = v({ break_response_code = 600 }, schema_def)
            assert.falsy(ok)
            assert.same("value should be between 200 and 599", err.config.break_response_code)
        end)
        it("invalid limit_by", function()
            local ok, err = v({ limit_by = "path" }, schema_def)
            assert.falsy(ok)
            assert.same("expected one of: host, host_path", err.config.limit_by)
        end)
        it("invalid max_breaker_sec", function()
            local ok, err = v({ max_breaker_sec = 0 }, schema_def)
            assert.falsy(ok)
            assert.same("value should be between 1 and 3600", err.config.max_breaker_sec)
        end)
        it("invalid max_breaker_sec", function()
            local ok, err = v({ max_breaker_sec = 0 }, schema_def)
            assert.falsy(ok)
            assert.same("value should be between 1 and 3600", err.config.max_breaker_sec)
        end)
        it("invalid unhealthy.failures", function()
            local ok, err = v({ unhealthy = { failures = 0 } }, schema_def)
            assert.falsy(ok)
            assert.same("value should be between 1 and 128", err.config.unhealthy.failures)
        end)
        it("invalid unhealthy.http_statuses type", function()
            local ok, err = v({ unhealthy = { http_statuses = "aa" } }, schema_def)
            assert.falsy(ok)
            assert.same('expected an array', err.config.unhealthy.http_statuses)
        end)
        it("invalid unhealthy.http_statuses element type", function()
            local ok, err = v({ unhealthy = { http_statuses = { "aa" } } }, schema_def)
            assert.falsy(ok)
            assert.same({ 'expected a number' }, err.config.unhealthy.http_statuses)
        end)
        it("invalid healthy.successes", function()
            local ok, err = v({ healthy = { successes = 0 } }, schema_def)
            assert.falsy(ok)
            assert.same("value should be between 1 and 128", err.config.healthy.successes)
        end)
        it("invalid healthy.http_statuses type", function()
            local ok, err = v({ healthy = { http_statuses = "aa" } }, schema_def)
            assert.falsy(ok)
            assert.same('expected an array', err.config.healthy.http_statuses)
        end)
        it("invalid healthy.http_statuses element type", function()
            local ok, err = v({ healthy = { http_statuses = { "aa" } } }, schema_def)
            assert.falsy(ok)
            assert.same({ 'expected a number' }, err.config.healthy.http_statuses)
        end)
        it("invalid whitelist type", function()
            local ok, err = v({ whitelist = "aa" }, schema_def)
            assert.falsy(ok)
            assert.same('expected an array', err.config.whitelist)
        end)
    end)
end)
