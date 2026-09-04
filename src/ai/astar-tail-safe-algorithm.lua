local Game = require("src.game")
local Grid = require("src.ai.shared.grid")
local Search = require("src.ai.shared.search")
local Simulation = require("src.ai.shared.simulation")

local function foodKey(world)
    return world.food and Game.cellKey(world.food.x, world.food.y, world.cols) or nil
end

local function safestFallback(world)
    local bestDirection, bestSpace = nil, -1
    for _, directionName in ipairs(Grid.legalDirections(world)) do
        local state = Simulation.fromGame(world)
        if Simulation.step(state, directionName) then
            local space = Simulation.floodFill(state)
            if space > bestSpace then
                bestDirection, bestSpace = directionName, space
            end
        end
    end
    return bestDirection
end

local function safeFoodPath(world)
    local path = Search.astar(world, world.food)
    if not path then
        return nil
    end
    local state = Simulation.fromGame(world)
    for _, directionName in ipairs(path) do
        local alive = Simulation.step(state, directionName)
        if not alive then
            return nil
        end
    end
    if #state.body == state.cols * state.rows or Search.tailReachable(state) then
        return path
    end
    return nil
end

return {
    id = "astar-tail-safe",
    label = "A* TAIL SAFE",
    tier = "CAUTIOUS",
    description = "Accepts a food path only when the simulated tail remains reachable.",
    reset = function()
        return { path = nil, foodKey = nil }
    end,
    chooseDirection = function(world, memory)
        local currentFoodKey = foodKey(world)
        local nextDirection = memory.path and memory.path[1] or nil
        if memory.foodKey ~= currentFoodKey or not nextDirection or not Grid.isSafe(world, nextDirection) then
            memory.path = safeFoodPath(world)
            memory.foodKey = currentFoodKey
        end
        if memory.path and #memory.path > 0 and Grid.isSafe(world, memory.path[1]) then
            return table.remove(memory.path, 1)
        end

        local tailPath = Search.bfs(world, world:tail())
        if tailPath and tailPath[1] and Grid.isSafe(world, tailPath[1]) then
            return tailPath[1]
        end
        return safestFallback(world) or world.direction
    end,
}
