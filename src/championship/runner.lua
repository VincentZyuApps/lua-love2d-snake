local BoardConfig = require("src.board")
local Game = require("src.game")
local GameFactory = require("src.factory")
local Registry = require("src.ai.algorithm-registry")
local Rng = require("src.rng")

local Runner = {}

local function gameSeed(config, dimensions, edgeMode, runIndex)
    return table.concat({
        config.masterSeed,
        "size=" .. dimensions.key,
        "edge=" .. edgeMode,
        "run=" .. tostring(runIndex),
    }, ":")
end

local function runGame(config, dimensions, edgeMode, algorithmId, runIndex)
    local seed = gameSeed(config, dimensions, edgeMode, runIndex)
    local game, aiRng = GameFactory.create({
        cols = dimensions.cols,
        rows = dimensions.rows,
        edgeMode = edgeMode,
        controlMode = "auto",
        seed = seed,
    })
    local algorithm = Registry.get(algorithmId)
    local context = { aiRng = aiRng or Rng.new(seed, 29) }
    local ok, memory = pcall(algorithm.reset, game, context)
    memory = ok and (memory or {}) or nil
    local stepCap = 2 * dimensions.cols * dimensions.rows * dimensions.cols * dimensions.rows
    local stagnationCap = dimensions.cols * dimensions.rows
    local lastFoodStep = 0
    local algorithmError = not ok

    while not algorithmError and game.status == "playing" and game.steps < stepCap
        and game.steps - lastFoodStep < stagnationCap do
        local chose, directionName = pcall(algorithm.chooseDirection, game, memory, context)
        if not chose or not Game.DIRECTIONS[directionName] then
            algorithmError = true
            break
        end
        local score = game.score
        game:step(directionName)
        if game.score > score then
            lastFoodStep = game.steps
        end
    end

    local outcome
    if algorithmError then
        outcome = "error"
    elseif game.status == "won" then
        outcome = "won"
    elseif game.status == "over" then
        outcome = "collision"
    else
        outcome = "timeout"
    end
    local totalCells = dimensions.cols * dimensions.rows
    return {
        size = dimensions.key,
        cols = dimensions.cols,
        rows = dimensions.rows,
        edge = edgeMode,
        algorithm = algorithmId,
        run = runIndex,
        seed = seed,
        outcome = outcome,
        score = game.score,
        finalLength = game:length(),
        totalCells = totalCells,
        fillRate = game:length() / totalCells,
        steps = game.steps,
        stepCap = stepCap,
        stagnationCap = stagnationCap,
        timeoutReason = outcome == "timeout" and (game.steps >= stepCap and "step-cap" or "stagnation") or nil,
        stepsPerFood = game.score > 0 and game.steps / game.score or nil,
    }
end

function Runner.run(config, progress)
    local games, errors = {}, 0
    for _, dimensions in ipairs(config.sizes) do
        local valid, message = BoardConfig.validate(dimensions.cols, dimensions.rows)
        assert(valid, message)
        for _, edgeMode in ipairs(config.edges) do
            for _, algorithmId in ipairs(config.algorithms) do
                for runIndex = 1, config.runs do
                    local game = runGame(config, dimensions, edgeMode, algorithmId, runIndex)
                    games[#games + 1] = game
                    if game.outcome == "error" then
                        errors = errors + 1
                    end
                    if progress then
                        progress(game, #games)
                    end
                    collectgarbage("collect")
                end
            end
        end
    end
    return games, errors
end

return Runner
