local BoardConfig = require("src.board")
local json = require("src.vendor.json")

local Settings = {}
Settings.__index = Settings
Settings.SCHEMA_VERSION = 1

function Settings.new(data)
    local cols = data and data.cols or BoardConfig.DEFAULT_COLS
    local rows = data and data.rows or BoardConfig.DEFAULT_ROWS
    local valid, message = BoardConfig.validate(cols, rows)
    assert(valid, message)
    return setmetatable({
        data = { version = Settings.SCHEMA_VERSION, cols = cols, rows = rows },
    }, Settings)
end

function Settings.fromJson(source)
    local data = json.decode(source)
    if type(data) ~= "table" or data.version ~= Settings.SCHEMA_VERSION then
        error("unsupported settings schema")
    end
    return Settings.new(data)
end

function Settings:toJson()
    return json.encode(self.data) .. "\n"
end

function Settings:setBoardSize(cols, rows)
    local valid, message = BoardConfig.validate(cols, rows)
    assert(valid, message)
    self.data.cols, self.data.rows = cols, rows
end

return Settings
