local Grid = require("src.ai.shared.grid")
local Search = require("src.ai.shared.search")
local Simulation = require("src.ai.shared.simulation")

local DEPTH = 10
local WIDTH = 24

local function evaluate(state, eaten)
    local foodBonus = eaten * 10000
    local tailBonus = Search.tailReachable(state) and 2000 or 0
    local space = Simulation.floodFill(state)
    local distance = Grid.distance(state, Grid.head(state), state.food)
    return foodBonus + tailBonus + space * 20 - distance * 5
end

return {
    id = "beam-search",
    label = "BEAM SEARCH",
    tier = "SEARCH",
    description = "Explores a depth-10, width-24 set of promising futures.",
    reset = function()
        return {}
    end,
    chooseDirection = function(world, _, context)
        local root = Simulation.fromGame(world)
        local beam = { { state = root, firstDirection = nil, eaten = 0, score = 0 } }

        for _ = 1, DEPTH do
            local candidates = {}
            local exhausted = false
            for _, node in ipairs(beam) do
                for _, directionName in ipairs(Grid.legalDirections(node.state)) do
                    local state = Simulation.clone(node.state)
                    local alive, ate = Simulation.step(state, directionName)
                    if alive then
                        local eaten = node.eaten + (ate and 1 or 0)
                        candidates[#candidates + 1] = {
                            state = state,
                            firstDirection = node.firstDirection or directionName,
                            eaten = eaten,
                            score = evaluate(state, eaten),
                        }
                    end
                    if context.isBudgetExceeded and context.isBudgetExceeded() then
                        exhausted = true
                        break
                    end
                end
                if exhausted then
                    break
                end
            end
            if #candidates == 0 then
                break
            end
            table.sort(candidates, function(left, right)
                return left.score > right.score
            end)
            beam = {}
            for index = 1, math.min(WIDTH, #candidates) do
                beam[index] = candidates[index]
            end
            if exhausted then
                break
            end
        end

        return beam[1] and beam[1].firstDirection or world.direction
    end,
}
