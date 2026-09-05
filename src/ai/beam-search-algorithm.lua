local Grid = require("src.ai.shared.grid")
local Search = require("src.ai.shared.search")
local Simulation = require("src.ai.shared.simulation")

local DEPTH = 10
local WIDTH = 24

local function evaluate(state, eaten)
    local foodBonus = eaten * 10000
    local area, bodyLength = state.cols * state.rows, #state.body
    local openBoard = bodyLength * 3 < area
    local tailBonus = (openBoard or Search.tailReachable(state)) and 2000 or 0
    local space = openBoard and area - bodyLength or Simulation.floodFill(state)
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
    chooseDirection = function(world)
        local root = Simulation.fromGame(world)
        local beam = { { state = root, firstDirection = nil, eaten = 0, score = 0 } }
        local expanded, serial = 0, 0
        local nodeBudget = math.max(8, math.floor(2048 / (world.cols * world.rows)))

        for _ = 1, DEPTH do
            local candidates = {}
            local exhausted = false
            for _, node in ipairs(beam) do
                for _, directionName in ipairs(Grid.legalDirections(node.state)) do
                    expanded = expanded + 1
                    if expanded > nodeBudget then
                        exhausted = true
                        break
                    end
                    local state = Simulation.clone(node.state)
                    local alive, ate = Simulation.step(state, directionName)
                    if alive then
                        serial = serial + 1
                        local eaten = node.eaten + (ate and 1 or 0)
                        candidates[#candidates + 1] = {
                            state = state,
                            firstDirection = node.firstDirection or directionName,
                            eaten = eaten,
                            score = evaluate(state, eaten),
                            serial = serial,
                        }
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
                return left.score > right.score or left.score == right.score and left.serial < right.serial
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
