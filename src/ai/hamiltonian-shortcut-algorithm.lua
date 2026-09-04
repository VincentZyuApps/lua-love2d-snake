local Cycle = require("src.ai.cycle-helpers")
local Grid = require("src.ai.shared.grid")

return {
    id = "hamiltonian-shortcut",
    label = "HAMILTONIAN SHORTCUT",
    tier = "GUARANTEED",
    description = "Takes food-directed shortcuts without overtaking the cycle tail.",
    guaranteed = true,
    reset = function()
        return {}
    end,
    chooseDirection = function(world)
        local cycle = Cycle.get()
        local head, tail = world:head(), world:tail()
        local headIndex = Cycle.indexOf(head.x, head.y)
        local tailIndex = Cycle.indexOf(tail.x, tail.y)
        local foodIndex = world.food and Cycle.indexOf(world.food.x, world.food.y) or nil
        if not headIndex or not tailIndex then
            local moves = Grid.legalDirections(world)
            return moves[1] or world.direction
        end

        local tailDistance = Cycle.forwardDistance(headIndex, tailIndex)
        local foodDistance = foodIndex and Cycle.forwardDistance(headIndex, foodIndex) or nil
        local bestDirection, bestAdvance
        for _, directionName in ipairs(Grid.legalDirections(world)) do
            local x, y = Grid.nextCell(world, directionName)
            local targetIndex = Cycle.indexOf(x, y)
            local advance = targetIndex and Cycle.forwardDistance(headIndex, targetIndex) or nil
            local beforeTail = advance and advance > 0 and advance < tailDistance
            local beforeFood = not foodDistance or foodDistance >= tailDistance or advance <= foodDistance
            if beforeTail and beforeFood and (bestAdvance == nil or advance > bestAdvance) then
                bestDirection, bestAdvance = directionName, advance
            end
        end

        if bestDirection then
            return bestDirection
        end
        local cycleDirection = cycle.directions[headIndex]
        if cycleDirection and Grid.isSafe(world, cycleDirection) then
            return cycleDirection
        end
        local moves = Grid.legalDirections(world)
        return moves[1] or world.direction
    end,
}
