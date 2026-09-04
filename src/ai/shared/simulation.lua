local Game = require("src.game")
local Grid = require("src.ai.shared.grid")

local Simulation = {}

local function copyCell(cell)
    return cell and { x = cell.x, y = cell.y } or nil
end

function Simulation.fromGame(game)
    local body = game:bodyCells()
    local occupied = {}
    for _, cell in ipairs(body) do
        occupied[Game.cellKey(cell.x, cell.y, game.cols)] = true
    end
    return {
        cols = game.cols,
        rows = game.rows,
        edgeMode = game.edgeMode,
        direction = game.direction,
        body = body,
        occupied = occupied,
        food = copyCell(game.food),
        score = game.score,
    }
end

function Simulation.clone(state)
    local body, occupied = {}, {}
    for _, cell in ipairs(state.body) do
        local copied = copyCell(cell)
        body[#body + 1] = copied
        occupied[Game.cellKey(copied.x, copied.y, state.cols)] = true
    end
    return {
        cols = state.cols,
        rows = state.rows,
        edgeMode = state.edgeMode,
        direction = state.direction,
        body = body,
        occupied = occupied,
        food = copyCell(state.food),
        score = state.score,
    }
end

function Simulation.step(state, directionName)
    if directionName == Game.DIRECTIONS[state.direction].opposite then
        return false, false
    end
    local nextX, nextY, outside = Grid.nextCell(state, directionName)
    if outside and state.edgeMode == "walls" then
        return false, false
    end

    local eating = state.food and nextX == state.food.x and nextY == state.food.y
    local tail = state.body[#state.body]
    local enteringTail = nextX == tail.x and nextY == tail.y
    if Grid.contains(state, nextX, nextY) and not (not eating and enteringTail) then
        return false, false
    end

    if not eating then
        local removed = table.remove(state.body)
        state.occupied[Game.cellKey(removed.x, removed.y, state.cols)] = nil
    end
    local head = { x = nextX, y = nextY }
    table.insert(state.body, 1, head)
    state.occupied[Game.cellKey(nextX, nextY, state.cols)] = true
    state.direction = directionName
    if eating then
        state.score = state.score + 1
        state.food = nil
    end
    return true, eating
end

function Simulation.floodFill(state)
    local start = Grid.head(state)
    local queue = { { x = start.x, y = start.y } }
    local first = 1
    local visited = { [Game.cellKey(start.x, start.y, state.cols)] = true }
    local count = 0

    while first <= #queue do
        local current = queue[first]
        first = first + 1
        count = count + 1
        for _, directionName in ipairs(Grid.order) do
            local x, y, outside = Grid.nextCell(state, directionName, current)
            local key = Game.cellKey(x, y, state.cols)
            if (not outside or state.edgeMode == "wrap") and not visited[key]
                and not Grid.contains(state, x, y) then
                visited[key] = true
                queue[#queue + 1] = { x = x, y = y }
            end
        end
    end
    return count
end

return Simulation
