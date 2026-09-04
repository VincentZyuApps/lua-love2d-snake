local Constants = require("src.constants")

local Game = {}
Game.__index = Game

Game.DIRECTIONS = {
    up = { x = 0, y = -1, opposite = "down" },
    down = { x = 0, y = 1, opposite = "up" },
    left = { x = -1, y = 0, opposite = "right" },
    right = { x = 1, y = 0, opposite = "left" },
}

local function copyCell(cell)
    return { x = cell.x, y = cell.y }
end

function Game.cellKey(x, y, cols)
    return (y - 1) * (cols or Constants.COLS) + x
end

function Game.new(options)
    local self = setmetatable({}, Game)
    self.cols = options.cols or Constants.COLS
    self.rows = options.rows or Constants.ROWS
    self.edgeMode = options.edgeMode or "walls"
    self.foodRng = assert(options.foodRng, "foodRng is required")
    self.direction = assert(options.initialDirection, "initialDirection is required")
    self.status = "playing"
    self.score = 0
    self.steps = 0
    self.food = nil
    self.tailFinishReady = false
    self.first = 0
    self.last = #options.initialCells - 1
    self.segments = {}
    self.occupied = {}

    for listIndex, cell in ipairs(options.initialCells) do
        local index = listIndex - 1
        local segment = copyCell(cell)
        self.segments[index] = segment
        self.occupied[Game.cellKey(segment.x, segment.y, self.cols)] = true
    end

    local firstFood = options.firstFood or { x = 21, y = 11 }
    if not self:contains(firstFood.x, firstFood.y) then
        self.food = copyCell(firstFood)
    else
        self:spawnFood()
    end
    return self
end

function Game:length()
    return self.last - self.first + 1
end

function Game:head()
    return self.segments[self.first]
end

function Game:tail()
    return self.segments[self.last]
end

function Game:contains(x, y)
    return self.occupied[Game.cellKey(x, y, self.cols)] == true
end

function Game:bodyCells()
    local cells = {}
    for index = self.first, self.last do
        cells[#cells + 1] = copyCell(self.segments[index])
    end
    return cells
end

function Game:nextCell(directionName, fromCell)
    local heading = assert(Game.DIRECTIONS[directionName], "unknown direction")
    local current = fromCell or self:head()
    local x, y = current.x + heading.x, current.y + heading.y
    local outside = x < 1 or x > self.cols or y < 1 or y > self.rows
    if outside and self.edgeMode == "wrap" then
        x = (x - 1) % self.cols + 1
        y = (y - 1) % self.rows + 1
    end
    return x, y, outside
end

function Game:isSafeDirection(directionName)
    if directionName == Game.DIRECTIONS[self.direction].opposite then
        return false
    end
    local x, y, outside = self:nextCell(directionName)
    if outside and self.edgeMode == "walls" then
        return false
    end
    if not self:contains(x, y) then
        return true
    end
    local eating = self.food and x == self.food.x and y == self.food.y
    local tail = self:tail()
    return not eating and x == tail.x and y == tail.y
end

function Game:spawnFood()
    local open = {}
    for y = 1, self.rows do
        for x = 1, self.cols do
            if not self:contains(x, y) then
                open[#open + 1] = { x = x, y = y }
            end
        end
    end
    if #open == 0 then
        self.food = nil
        self.tailFinishReady = true
        return false
    end
    self.food = open[self.foodRng:integer(#open)]
    return true
end

function Game:step(directionName)
    if self.status ~= "playing" then
        return { status = self.status }
    end
    self.steps = self.steps + 1
    self.direction = directionName
    local nextX, nextY, outside = self:nextCell(directionName)
    if outside and self.edgeMode == "walls" then
        self.status = "over"
        return { status = self.status, died = true }
    end

    local eating = self.food and nextX == self.food.x and nextY == self.food.y
    local tail = self:tail()
    local enteringTail = nextX == tail.x and nextY == tail.y
    if self:contains(nextX, nextY) and not (not eating and enteringTail) then
        self.status = "over"
        return { status = self.status, died = true }
    end

    if not eating then
        self.occupied[Game.cellKey(tail.x, tail.y, self.cols)] = nil
        self.segments[self.last] = nil
        self.last = self.last - 1
    end

    self.first = self.first - 1
    local nextHead = { x = nextX, y = nextY }
    self.segments[self.first] = nextHead
    self.occupied[Game.cellKey(nextX, nextY, self.cols)] = true

    if self.tailFinishReady and enteringTail and self:length() == self.cols * self.rows then
        self.status = "won"
        return { status = self.status, won = true }
    end

    if eating then
        self.score = self.score + 1
        self:spawnFood()
        return { status = self.status, ate = true }
    end
    return { status = self.status }
end

function Game:stateSignature()
    local parts = { self.status, self.edgeMode, self.direction, tostring(self.score), tostring(self.steps) }
    for index = self.first, self.last do
        local cell = self.segments[index]
        parts[#parts + 1] = cell.x .. ":" .. cell.y
    end
    parts[#parts + 1] = self.food and (self.food.x .. ":" .. self.food.y) or "none"
    return table.concat(parts, "|")
end

return Game
