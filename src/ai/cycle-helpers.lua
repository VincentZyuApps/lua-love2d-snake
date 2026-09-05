local Cycle = {}
local cache = {}

local function key(x, y, cols)
    return (y - 1) * cols + x
end

local function evenWidthCells(cols, rows)
    local cells = {}
    for x = 1, cols do
        cells[#cells + 1] = { x = x, y = 1 }
    end
    for y = 2, rows do
        cells[#cells + 1] = { x = cols, y = y }
    end
    local currentY = rows
    for x = cols - 1, 2, -1 do
        cells[#cells + 1] = { x = x, y = currentY }
        local targetY = currentY == rows and 2 or rows
        local step = targetY > currentY and 1 or -1
        for y = currentY + step, targetY, step do
            cells[#cells + 1] = { x = x, y = y }
        end
        currentY = targetY
    end
    assert(currentY == rows, "generated cycle cannot close")
    for y = rows, 2, -1 do
        cells[#cells + 1] = { x = 1, y = y }
    end
    return cells
end

local function directionBetween(fromCell, toCell)
    local dx, dy = toCell.x - fromCell.x, toCell.y - fromCell.y
    if dx == 1 then return "right" end
    if dx == -1 then return "left" end
    if dy == 1 then return "down" end
    if dy == -1 then return "up" end
    error("Hamiltonian cycle contains non-adjacent cells")
end

local function build(cols, rows)
    assert(cols >= 2 and rows >= 2 and (cols % 2 == 0 or rows % 2 == 0),
        "Hamiltonian cycle requires at least one even dimension")
    local cells
    if cols % 2 == 0 then
        cells = evenWidthCells(cols, rows)
    else
        cells = {}
        for _, cell in ipairs(evenWidthCells(rows, cols)) do
            cells[#cells + 1] = { x = cell.y, y = cell.x }
        end
    end
    assert(#cells == cols * rows, "Hamiltonian cycle must cover the board")

    local index, directions = {}, {}
    for position, cell in ipairs(cells) do
        local cellKey = key(cell.x, cell.y, cols)
        assert(not index[cellKey], "Hamiltonian cycle visits a cell more than once")
        index[cellKey] = position
        directions[position] = directionBetween(cell, cells[position % #cells + 1])
    end
    return { cols = cols, rows = rows, cells = cells, index = index, directions = directions, size = #cells }
end

function Cycle.get(cols, rows)
    local cacheKey = tostring(cols) .. "x" .. tostring(rows)
    if not cache[cacheKey] then
        cache[cacheKey] = build(cols, rows)
    end
    return cache[cacheKey]
end

function Cycle.clearCache()
    cache = {}
end

function Cycle.indexOf(cycle, x, y)
    return cycle.index[key(x, y, cycle.cols)]
end

function Cycle.forwardDistance(cycle, fromIndex, toIndex)
    return (toIndex - fromIndex) % cycle.size
end

function Cycle.initialSnake(cols, rows, headX, headY, length)
    local cycle = Cycle.get(cols, rows)
    local headIndex = assert(Cycle.indexOf(cycle, headX, headY), "initial head is not on the cycle")
    local cells = {}
    for offset = 0, length - 1 do
        local index = ((headIndex - 1 - offset) % cycle.size) + 1
        local cell = cycle.cells[index]
        cells[#cells + 1] = { x = cell.x, y = cell.y }
    end
    return cells, cycle.directions[headIndex]
end

return Cycle
