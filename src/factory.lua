local BoardConfig = require("src.board")
local Cycle = require("src.ai.cycle-helpers")
local Game = require("src.game")
local Rng = require("src.rng")

local GameFactory = {}
GameFactory.INITIAL_LENGTH = 4

local function centeredCoordinate(size)
    return math.floor((size + 1) / 2)
end

local function manualSnake(cols, rows, directionName)
    local heading = assert(Game.DIRECTIONS[directionName], "unknown initial direction")
    local headX, headY = centeredCoordinate(cols), centeredCoordinate(rows)
    if heading.x > 0 then
        headX = math.max(headX, GameFactory.INITIAL_LENGTH)
    elseif heading.x < 0 then
        headX = math.min(headX, cols - GameFactory.INITIAL_LENGTH + 1)
    elseif heading.y > 0 then
        headY = math.max(headY, GameFactory.INITIAL_LENGTH)
    else
        headY = math.min(headY, rows - GameFactory.INITIAL_LENGTH + 1)
    end

    local cells = {}
    for offset = 0, GameFactory.INITIAL_LENGTH - 1 do
        cells[#cells + 1] = { x = headX - heading.x * offset, y = headY - heading.y * offset }
    end
    return cells, directionName
end

local function firstFood(cols, rows, occupied)
    local targetX = math.max(1, math.min(cols, math.floor(cols * 0.7 + 0.5)))
    local targetY = centeredCoordinate(rows)
    local best, bestDistance
    for y = 1, rows do
        for x = 1, cols do
            if not occupied[Game.cellKey(x, y, cols)] then
                local distance = math.abs(x - targetX) + math.abs(y - targetY)
                if not bestDistance or distance < bestDistance then
                    best, bestDistance = { x = x, y = y }, distance
                end
            end
        end
    end
    return assert(best, "initial snake leaves no food cell")
end

function GameFactory.create(options)
    options = options or {}
    local cols = options.cols or BoardConfig.DEFAULT_COLS
    local rows = options.rows or BoardConfig.DEFAULT_ROWS
    local valid, message = BoardConfig.validate(cols, rows)
    assert(valid, message)

    local cells, directionName
    if options.controlMode == "manual" then
        cells, directionName = manualSnake(cols, rows, options.initialDirection or "right")
    else
        cells, directionName = Cycle.initialSnake(
            cols, rows, centeredCoordinate(cols), centeredCoordinate(rows), GameFactory.INITIAL_LENGTH)
    end

    local occupied = {}
    for _, cell in ipairs(cells) do
        occupied[Game.cellKey(cell.x, cell.y, cols)] = true
    end
    local seed = tostring(options.seed or "default")
    local foodRng = Rng.new(seed, 11)
    local aiRng = Rng.new(seed, 29)
    local game = Game.new({
        cols = cols,
        rows = rows,
        edgeMode = options.edgeMode or "walls",
        initialCells = cells,
        initialDirection = directionName,
        foodRng = foodRng,
        firstFood = firstFood(cols, rows, occupied),
    })
    return game, aiRng, foodRng
end

return GameFactory
