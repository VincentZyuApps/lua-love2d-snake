local Constants = require("src.constants")
local routeData = require("src.ai.cycle-data")

local Cycle = {}

local directionByMove = {
    U = { name = "up", x = 0, y = -1 },
    D = { name = "down", x = 0, y = 1 },
    L = { name = "left", x = -1, y = 0 },
    R = { name = "right", x = 1, y = 0 },
}

local function key(x, y, cols)
    return (y - 1) * cols + x
end

local function build()
    local cols, rows = Constants.COLS, Constants.ROWS
    assert(routeData.cols == cols and routeData.rows == rows, "AI route dimensions do not match the board")
    assert(#routeData.moves == cols * rows, "AI route must contain one move per cell")

    local cells = { { x = 1, y = 1 } }
    local index = { [key(1, 1, cols)] = 1 }
    local directions = {}
    local x, y = 1, 1

    for moveIndex = 1, #routeData.moves do
        local move = directionByMove[routeData.moves:sub(moveIndex, moveIndex)]
        assert(move, "AI route contains an unknown move")
        directions[moveIndex] = move.name
        x, y = x + move.x, y + move.y
        if moveIndex < #routeData.moves then
            assert(x >= 1 and x <= cols and y >= 1 and y <= rows, "AI route leaves the board")
            local cellKey = key(x, y, cols)
            assert(not index[cellKey], "AI route visits a cell more than once")
            cells[#cells + 1] = { x = x, y = y }
            index[cellKey] = #cells
        end
    end

    assert(x == 1 and y == 1, "AI route is not a closed cycle")
    assert(#cells == cols * rows, "AI route does not cover the board")
    return { cells = cells, index = index, directions = directions, size = #cells }
end

local instance = build()

function Cycle.get()
    return instance
end

function Cycle.indexOf(x, y)
    return instance.index[key(x, y, Constants.COLS)]
end

function Cycle.forwardDistance(fromIndex, toIndex)
    return (toIndex - fromIndex) % instance.size
end

function Cycle.initialSnake(headX, headY, length)
    local headIndex = assert(Cycle.indexOf(headX, headY), "initial head is not on the cycle")
    local cells = {}
    for offset = 0, length - 1 do
        local index = ((headIndex - 1 - offset) % instance.size) + 1
        local cell = instance.cells[index]
        cells[#cells + 1] = { x = cell.x, y = cell.y }
    end
    return cells, instance.directions[headIndex]
end

return Cycle
