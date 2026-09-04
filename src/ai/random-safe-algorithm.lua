local Grid = require("src.ai.shared.grid")

return {
    id = "random-safe",
    label = "RANDOM SAFE",
    tier = "RISKY",
    description = "Randomly chooses an immediately safe move.",
    reset = function()
        return {}
    end,
    chooseDirection = function(world, _, context)
        local moves = Grid.legalDirections(world)
        if #moves == 0 then
            return world.direction
        end
        return moves[context.aiRng:integer(#moves)]
    end,
}
