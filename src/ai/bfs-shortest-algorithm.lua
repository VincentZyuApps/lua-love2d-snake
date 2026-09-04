local Game = require("src.game")
local Grid = require("src.ai.shared.grid")
local Search = require("src.ai.shared.search")

local function foodKey(world)
    return world.food and Game.cellKey(world.food.x, world.food.y, world.cols) or nil
end

return {
    id = "bfs-shortest",
    label = "BFS SHORTEST",
    tier = "RISKY",
    description = "Caches a shortest route to food without looking beyond it.",
    reset = function()
        return { path = nil, foodKey = nil }
    end,
    chooseDirection = function(world, memory)
        local currentFoodKey = foodKey(world)
        local nextDirection = memory.path and memory.path[1] or nil
        if memory.foodKey ~= currentFoodKey or not nextDirection or not Grid.isSafe(world, nextDirection) then
            memory.path = Search.bfs(world, world.food)
            memory.foodKey = currentFoodKey
        end
        if memory.path and #memory.path > 0 and Grid.isSafe(world, memory.path[1]) then
            return table.remove(memory.path, 1)
        end
        local moves = Grid.legalDirections(world)
        return moves[1] or world.direction
    end,
}
