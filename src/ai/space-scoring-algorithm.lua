local Grid = require("src.ai.shared.grid")
local Search = require("src.ai.shared.search")
local Simulation = require("src.ai.shared.simulation")

local SpaceScoring = {
    id = "space-scoring",
    label = "SPACE SCORING",
    tier = "CAUTIOUS",
    description = "Scores food distance, reachable space, and tail connectivity.",
}

function SpaceScoring.reset()
    return {}
end

function SpaceScoring.scoreMove(world, directionName)
    local state = Simulation.fromGame(world)
    local alive, ate = Simulation.step(state, directionName)
    if not alive then
        return -math.huge
    end
    local space = Simulation.floodFill(state)
    local tailBonus = Search.tailReachable(state) and 2000 or 0
    local distance = Grid.distance(state, Grid.head(state), state.food)
    local foodBonus = ate and 10000 or 0
    return foodBonus + tailBonus + space * 20 - distance * 5
end

function SpaceScoring.chooseDirection(world)
    local bestDirection, bestScore
    for _, directionName in ipairs(Grid.legalDirections(world)) do
        local score = SpaceScoring.scoreMove(world, directionName)
        if bestScore == nil or score > bestScore then
            bestDirection, bestScore = directionName, score
        end
    end
    return bestDirection or world.direction
end

return SpaceScoring
