local socket = require "socket"
local helpers = require "spec.helpers"
local fixtures = require "spec.circuit-breaker.fixtures"

local strategies = { "postgres" }

for _, strategy in ipairs(strategies) do
    describe("circuit breaker plugin [#" .. strategy .. "]", function()
        local bp, db
        local mock_host = helpers.mock_upstream_host;
        local mock_port = 10000

        local function do_request(host, http_status_to_be_generated, http_status_expected)
            local proxy_client = helpers.proxy_client()
            local res = assert(
                    proxy_client:send({
                        path = "/foo/bar",
                        headers = {
                            Host = host,
                            response_http_code = http_status_to_be_generated,
                        },
                    }))
            assert.are.same(http_status_expected, res.status)
            proxy_client:close()
        end

        lazy_setup(function()
            bp, db = helpers.get_db_utils(strategy, {
                "routes",
                "services",
                "plugins",
            }, { "circuit-breaker" })

            local srv = assert(bp.services:insert({
                protocol = "http",
                host = mock_host,
                port = mock_port,
                name = "test",
            }))

            local route1 = assert(bp.routes:insert({
                methods = { "GET" },
                protocols = { "http" },
                hosts = { "api1.circuit-breaker.com" },
                strip_path = false,
                preserve_host = true,
                service = { id = srv.id },
            }))

            local route2 = assert(bp.routes:insert({
                methods = { "GET" },
                protocols = { "http" },
                hosts = { "api2.circuit-breaker.com" },
                strip_path = false,
                preserve_host = true,
                service = { id = srv.id },
            }))

            local route3 = assert(bp.routes:insert({
                methods = { "GET" },
                protocols = { "http" },
                hosts = { "api3.circuit-breaker.com" },
                strip_path = false,
                preserve_host = true,
                service = { id = srv.id },
            }))

            local route4 = assert(bp.routes:insert({
                methods = { "GET" },
                protocols = { "http" },
                hosts = { "api4.circuit-breaker.com" },
                strip_path = false,
                preserve_host = true,
                service = { id = srv.id },
            }))

            bp.plugins:insert {
                name = "circuit-breaker",
                route = { id = route1.id },
                config = { whitelist = { "^/foo/bar$" } },
            }

            bp.plugins:insert {
                name = "circuit-breaker",
                route = { id = route2.id },
                config = {},
            }

            bp.plugins:insert {
                name = "circuit-breaker",
                route = { id = route3.id },
                config = { unhealthy = { http_statuses = { 500 }, failures = 1 }, break_response_code = 599 },
            }

            bp.plugins:insert {
                name = "circuit-breaker",
                route = { id = route4.id },
                config = {},
            }

            assert(helpers.start_kong({
                database = strategy,
                plugins = "circuit-breaker",
                nginx_conf = "spec/fixtures/custom_nginx.template"
            }, nil, nil, fixtures.fixtures))
        end)

        lazy_teardown(function()
            db:truncate()
            helpers.stop_kong()
        end)

        it("assert whitelist", function()
            local host = "api1.circuit-breaker.com"
            for _ = 1, 6, 1 do
                do_request(host, 504, 504)
            end
        end)

        it("no circuit breaker triggered", function()
            local host = "api2.circuit-breaker.com"
            for _ = 1, 6, 1 do
                do_request(host, 500, 500)
            end
        end)

        it("circuit breaker trigger", function()
            local host = "api3.circuit-breaker.com"
            do_request(host, 500, 500)
            for _ = 1, 6, 1 do
                do_request(host, 500, 599)
            end
        end)

        it("circuit breaker recovery", function()
            local host = "api4.circuit-breaker.com"
            -- Trigger 3 times 504 status code
            do_request(host, 504, 504)
            do_request(host, 504, 504)
            do_request(host, 504, 504)

            -- The circuit breaker is triggered for the first time and lasts for 2s
            do_request(host, 504, 503)
            do_request(host, 504, 503)

            -- After 3s, enter the semi-state, allowing continued detection
            socket.select(nil, nil, 3)
            do_request(host, 504, 504)
            do_request(host, 504, 504)
            do_request(host, 504, 504)

            -- The circuit breaker is triggered again and will lasts for 4s
            do_request(host, 504, 503)
            do_request(host, 504, 503)

            -- After 2s, still in circuit breaker state
            socket.select(nil, nil, 2)
            do_request(host, 504, 503)
            do_request(host, 504, 503)
            do_request(host, 504, 503)

            -- After 3s, enter the semi-state, allowing continued detection
            socket.select(nil, nil, 3)
            do_request(host, 504, 504)
            do_request(host, 504, 504)

            -- Trigger success status code, enter recovery procedure, clear failure count
            do_request(host, 200, 200)
            do_request(host, 200, 200)
            do_request(host, 200, 200)

            -- Trigger 3 times 504 status code and enter circuit breaker
            do_request(host, 504, 504)
            do_request(host, 504, 504)
            do_request(host, 504, 504)

            -- Enter circuit breaker
            do_request(host, 504, 503)

            -- After 3 seconds, it goes into a semi-fused state.
            -- (Here it is 3 seconds, not 8 seconds, which can prove the success of the 3 times 200 clear failure count)
            socket.select(nil, nil, 3)
            do_request(host, 504, 504)
        end)
    end)
end