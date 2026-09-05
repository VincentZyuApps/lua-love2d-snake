local Cycle = require("src.ai.cycle-helpers")
local Grid = require("src.ai.shared.grid")

return {
    id = "hamiltonian",
    label = "HAMILTONIAN",
    tier = "GUARANTEED",
    description = "Follows a complete Hamiltonian cycle without shortcuts.",
    guaranteed = true,
    reset = function()
        return {}
    end,
    chooseDirection = function(world)
        local head = world:head()
        local cycle = Cycle.get(world.cols, world.rows)
        local index = Cycle.indexOf(cycle, head.x, head.y)
        local directionName = index and cycle.directions[index] or nil
        if directionName and Grid.isSafe(world, directionName) then
            return directionName
        end
        local moves = Grid.legalDirections(world)
        return moves[1] or world.direction
    end,
}
