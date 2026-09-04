local Game = require("src.game")
local Grid = require("src.ai.shared.grid")

local Search = {}

local function reconstruct(world, parents, targetKey)
    local path = {}
    local key = targetKey
    while parents[key] do
        table.insert(path, 1, parents[key].direction)
        key = parents[key].previous
    end
    return path
end

local function canVisit(world, x, y, targetKey)
    local key = Game.cellKey(x, y, world.cols)
    if key == targetKey then
        return true
    end
    local tail = Grid.tail(world)
    if tail and x == tail.x and y == tail.y then
        return true
    end
    return not Grid.contains(world, x, y)
end

function Search.bfs(world, target)
    if not target then
        return nil
    end
    local start = Grid.head(world)
    if start.x == target.x and start.y == target.y then
        return {}
    end

    local startKey = Game.cellKey(start.x, start.y, world.cols)
    local targetKey = Game.cellKey(target.x, target.y, world.cols)
    local queue = { { x = start.x, y = start.y } }
    local first = 1
    local visited = { [startKey] = true }
    local parents = {}

    while first <= #queue do
        local current = queue[first]
        first = first + 1
        for _, directionName in ipairs(Grid.order) do
            if not (current.x == start.x and current.y == start.y
                and directionName == Game.DIRECTIONS[world.direction].opposite) then
                local x, y, outside = Grid.nextCell(world, directionName, current)
                local key = Game.cellKey(x, y, world.cols)
                if (not outside or world.edgeMode == "wrap") and not visited[key]
                    and canVisit(world, x, y, targetKey) then
                    visited[key] = true
                    parents[key] = {
                        previous = Game.cellKey(current.x, current.y, world.cols),
                        direction = directionName,
                    }
                    if key == targetKey then
                        return reconstruct(world, parents, targetKey)
                    end
                    queue[#queue + 1] = { x = x, y = y }
                end
            end
        end
    end
    return nil
end

function Search.astar(world, target)
    if not target then
        return nil
    end
    local start = Grid.head(world)
    if start.x == target.x and start.y == target.y then
        return {}
    end

    local startKey = Game.cellKey(start.x, start.y, world.cols)
    local targetKey = Game.cellKey(target.x, target.y, world.cols)
    local open = { { x = start.x, y = start.y, key = startKey, g = 0, f = Grid.distance(world, start, target) } }
    local costs = { [startKey] = 0 }
    local parents, closed = {}, {}

    while #open > 0 do
        local bestIndex = 1
        for index = 2, #open do
            if open[index].f < open[bestIndex].f
                or (open[index].f == open[bestIndex].f and open[index].g < open[bestIndex].g) then
                bestIndex = index
            end
        end
        local current = table.remove(open, bestIndex)
        if not closed[current.key] then
            closed[current.key] = true
            if current.key == targetKey then
                return reconstruct(world, parents, targetKey)
            end
            for _, directionName in ipairs(Grid.order) do
                if not (current.key == startKey and directionName == Game.DIRECTIONS[world.direction].opposite) then
                    local from = { x = current.x, y = current.y }
                    local x, y, outside = Grid.nextCell(world, directionName, from)
                    local key = Game.cellKey(x, y, world.cols)
                    if (not outside or world.edgeMode == "wrap") and not closed[key]
                        and canVisit(world, x, y, targetKey) then
                        local cost = current.g + 1
                        if costs[key] == nil or cost < costs[key] then
                            costs[key] = cost
                            parents[key] = { previous = current.key, direction = directionName }
                            open[#open + 1] = {
                                x = x,
                                y = y,
                                key = key,
                                g = cost,
                                f = cost + Grid.distance(world, { x = x, y = y }, target),
                            }
                        end
                    end
                end
            end
        end
    end
    return nil
end

function Search.tailReachable(world)
    local tail = Grid.tail(world)
    local path = tail and Search.bfs(world, tail) or nil
    return path ~= nil
end

return Search
