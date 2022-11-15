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

local ngx = ngx
local typedefs = require "kong.db.schema.typedefs"

local function validate_shared_dict()
    if not ngx.shared.kong_circuit_breaker then
        return nil, "ngx shared dict 'kong_circuit_breaker' not found"
    end
    return true
end

return {
    name = "circuit-breaker",
    fields = {
        { protocols = typedefs.protocols_http },
        { config = {
            type = "record",
            fields = {
                { break_response_code = { type = "number", default = 503, between = { 200, 599 } } },
                { limit_by = { type = "string", default = "host", one_of = { "host", "host_path" } } },
                { max_breaker_sec = { type = "number", default = 32, between = { 1, 3600 } } },
                { unhealthy = {
                    type = "record",
                    fields = {
                        { http_statuses = { type = "array", elements = { type = "number", default = 502, between = { 200, 599 } }, default = { 502, 503, 504 } } },
                        { failures = { type = "number", default = 3, between = { 1, 128 } } } }
                }, },
                { healthy = {
                    type = "record",
                    fields = {
                        { http_statuses = { type = "array", elements = { type = "number", default = 200, between = { 200, 599 } }, default = { 200 } } },
                        { successes = { type = "number", default = 3, between = { 1, 128 } } } }
                }, },
                { whitelist = { type = "array", elements = { type = "string", is_regex = true }, default = {}, }, },
            },
            custom_validator = validate_shared_dict,
        } }
    }
}
