local Game = require("src.game")
local Grid = require("src.ai.shared.grid")

local Search = {}

local function reconstruct(parents, targetKey)
    local path = {}
    local key = targetKey
    while parents[key] do
        path[#path + 1] = parents[key].direction
        key = parents[key].previous
    end
    for left = 1, math.floor(#path / 2) do
        local right = #path - left + 1
        path[left], path[right] = path[right], path[left]
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

local function breadthFirst(world, target, buildPath)
    if not target then
        return nil
    end
    local start = Grid.head(world)
    if start.x == target.x and start.y == target.y then
        return buildPath and {} or true
    end

    local startKey = Game.cellKey(start.x, start.y, world.cols)
    local targetKey = Game.cellKey(target.x, target.y, world.cols)
    local queue = { { x = start.x, y = start.y } }
    local first = 1
    local visited = { [startKey] = true }
    local parents = buildPath and {} or nil

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
                    if buildPath then
                        parents[key] = {
                            previous = Game.cellKey(current.x, current.y, world.cols),
                            direction = directionName,
                        }
                    end
                    if key == targetKey then
                        return buildPath and reconstruct(parents, targetKey) or true
                    end
                    queue[#queue + 1] = { x = x, y = y }
                end
            end
        end
    end
    return nil
end

function Search.bfs(world, target)
    return breadthFirst(world, target, true)
end

function Search.reachable(world, target)
    return breadthFirst(world, target, false) == true
end

local function comesBefore(left, right)
    return left.f < right.f
        or left.f == right.f and (left.g < right.g
            or left.g == right.g and left.serial < right.serial)
end

local function heapPush(heap, node)
    local index = #heap + 1
    while index > 1 do
        local parent = math.floor(index / 2)
        if not comesBefore(node, heap[parent]) then
            break
        end
        heap[index] = heap[parent]
        index = parent
    end
    heap[index] = node
end

local function heapPop(heap)
    local root = heap[1]
    local last = table.remove(heap)
    if #heap == 0 then
        return root
    end

    local index = 1
    while index * 2 <= #heap do
        local child = index * 2
        if child + 1 <= #heap and comesBefore(heap[child + 1], heap[child]) then
            child = child + 1
        end
        if not comesBefore(heap[child], last) then
            break
        end
        heap[index] = heap[child]
        index = child
    end
    heap[index] = last
    return root
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
    local open = {}
    local serial = 1
    heapPush(open, {
        x = start.x,
        y = start.y,
        key = startKey,
        g = 0,
        f = Grid.distance(world, start, target),
        serial = serial,
    })
    local costs = { [startKey] = 0 }
    local parents, closed = {}, {}

    while #open > 0 do
        local current = heapPop(open)
        if not closed[current.key] then
            closed[current.key] = true
            if current.key == targetKey then
                return reconstruct(parents, targetKey)
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
                            serial = serial + 1
                            heapPush(open, {
                                x = x,
                                y = y,
                                key = key,
                                g = cost,
                                f = cost + Grid.distance(world, { x = x, y = y }, target),
                                serial = serial,
                            })
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
    return tail ~= nil and Search.reachable(world, tail)
end

return Search
