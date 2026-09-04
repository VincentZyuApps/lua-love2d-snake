local Grid = require("src.ai.shared.grid")

return {
    id = "greedy",
    label = "GREEDY",
    tier = "RISKY",
    description = "Moves toward food without evaluating the resulting trap.",
    reset = function()
        return {}
    end,
    chooseDirection = function(world)
        local moves = Grid.legalDirections(world)
        local bestDirection, bestDistance
        for _, directionName in ipairs(moves) do
            local x, y = Grid.nextCell(world, directionName)
            local distance = Grid.distance(world, { x = x, y = y }, world.food)
            if bestDistance == nil or distance < bestDistance then
                bestDirection, bestDistance = directionName, distance
            end
        end
        return bestDirection or world.direction
    end,
}
