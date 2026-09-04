local Game = require("src.game")

local Grid = {}

Grid.order = { "up", "right", "down", "left" }
Grid.clockwise = { up = "right", right = "down", down = "left", left = "up" }
Grid.counterClockwise = { up = "left", left = "down", down = "right", right = "up" }

function Grid.head(world)
    return world.head and world:head() or world.body[1]
end

function Grid.tail(world)
    return world.tail and world:tail() or world.body[#world.body]
end

function Grid.contains(world, x, y)
    if world.contains then
        return world:contains(x, y)
    end
    return world.occupied[Game.cellKey(x, y, world.cols)] == true
end

function Grid.nextCell(world, directionName, fromCell)
    local heading = Game.DIRECTIONS[directionName]
    local current = fromCell or Grid.head(world)
    local x, y = current.x + heading.x, current.y + heading.y
    local outside = x < 1 or x > world.cols or y < 1 or y > world.rows
    if outside and world.edgeMode == "wrap" then
        x = (x - 1) % world.cols + 1
        y = (y - 1) % world.rows + 1
    end
    return x, y, outside
end

function Grid.preference(directionName)
    return {
        directionName,
        Grid.clockwise[directionName],
        Grid.counterClockwise[directionName],
        Game.DIRECTIONS[directionName].opposite,
    }
end

function Grid.isSafe(world, directionName)
    if directionName == Game.DIRECTIONS[world.direction].opposite then
        return false
    end
    local x, y, outside = Grid.nextCell(world, directionName)
    if outside and world.edgeMode == "walls" then
        return false
    end
    if not Grid.contains(world, x, y) then
        return true
    end
    local eating = world.food and x == world.food.x and y == world.food.y
    local tail = Grid.tail(world)
    return not eating and x == tail.x and y == tail.y
end

function Grid.legalDirections(world)
    local result = {}
    for _, directionName in ipairs(Grid.preference(world.direction)) do
        if Grid.isSafe(world, directionName) then
            result[#result + 1] = directionName
        end
    end
    return result
end

function Grid.distance(world, fromCell, toCell)
    if not toCell then
        return 0
    end
    local dx = math.abs(fromCell.x - toCell.x)
    local dy = math.abs(fromCell.y - toCell.y)
    if world.edgeMode == "wrap" then
        dx = math.min(dx, world.cols - dx)
        dy = math.min(dy, world.rows - dy)
    end
    return dx + dy
end

function Grid.directionBetween(world, fromCell, toCell)
    for _, directionName in ipairs(Grid.order) do
        local x, y, outside = Grid.nextCell(world, directionName, fromCell)
        if (not outside or world.edgeMode == "wrap") and x == toCell.x and y == toCell.y then
            return directionName
        end
    end
end

return Grid
