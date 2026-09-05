local BoardConfig = {}

BoardConfig.MIN_SIZE = 5
BoardConfig.MAX_SIZE = 50
BoardConfig.DEFAULT_COLS = 30
BoardConfig.DEFAULT_ROWS = 21
BoardConfig.PRESETS = {
    { cols = 10, rows = 8 },
    { cols = 20, rows = 14 },
    { cols = 30, rows = 21 },
    { cols = 40, rows = 28 },
    { cols = 50, rows = 50 },
}

function BoardConfig.validate(cols, rows)
    if type(cols) ~= "number" or type(rows) ~= "number"
        or cols ~= math.floor(cols) or rows ~= math.floor(rows) then
        return false, "WIDTH AND HEIGHT MUST BE WHOLE NUMBERS"
    end
    if cols < BoardConfig.MIN_SIZE or cols > BoardConfig.MAX_SIZE
        or rows < BoardConfig.MIN_SIZE or rows > BoardConfig.MAX_SIZE then
        return false, "WIDTH AND HEIGHT MUST BE BETWEEN 5 AND 50"
    end
    if cols % 2 == 1 and rows % 2 == 1 then
        return false, "AT LEAST ONE DIMENSION MUST BE EVEN"
    end
    return true
end

function BoardConfig.key(cols, rows)
    return tostring(cols) .. "x" .. tostring(rows)
end

function BoardConfig.parse(value)
    local cols, rows = tostring(value or ""):match("^(%d+)[xX](%d+)$")
    cols, rows = tonumber(cols), tonumber(rows)
    local valid, message = BoardConfig.validate(cols, rows)
    if not valid then
        return nil, nil, message
    end
    return cols, rows
end

return BoardConfig
