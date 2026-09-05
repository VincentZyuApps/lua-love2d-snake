package.path = "./?.lua;./?/init.lua;" .. package.path

local Arguments = require("src.championship.arguments")

local config = Arguments.parse(arg or {})
local entries = {}
for _, dimensions in ipairs(config.sizes) do
    for _, edge in ipairs(config.edges) do
        entries[#entries + 1] = string.format(
            '{"size":"%s","cols":%d,"rows":%d,"edge":"%s"}',
            dimensions.key, dimensions.cols, dimensions.rows, edge)
    end
end
print('{"include":[' .. table.concat(entries, ",") .. "]}")
