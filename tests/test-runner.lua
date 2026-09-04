local Cycle = require("src.ai.cycle-helpers")
local Constants = require("src.constants")
local ControlSession = require("src.ai.control-session")
local Game = require("src.game")
local Grid = require("src.ai.shared.grid")
local Registry = require("src.ai.algorithm-registry")
local Rng = require("src.rng")
local Search = require("src.ai.shared.search")
local Stats = require("src.stats")
local Storage = require("src.storage")

local Suite = {}
local tests = {}

local function test(name, callback)
    tests[#tests + 1] = { name = name, callback = callback }
end

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function assertTrue(value, message)
    if not value then
        error(message or "expected a truthy value")
    end
end

local function newAiGame(edgeMode, seed)
    local cells, directionName = Cycle.initialSnake(15, 11, 4)
    return Game.new({
        edgeMode = edgeMode,
        initialCells = cells,
        initialDirection = directionName,
        foodRng = Rng.new(seed, 11),
        firstFood = { x = 21, y = 11 },
    })
end

local function algorithmContext(seed)
    return {
        aiRng = Rng.new(seed, 29),
        isBudgetExceeded = function()
            return false
        end,
    }
end

local function simulateToEnd(algorithmId, edgeMode, seed, maximumSteps)
    local game = newAiGame(edgeMode, seed)
    local algorithm = Registry.get(algorithmId)
    local context = algorithmContext(seed)
    local memory = algorithm.reset(game, context) or {}
    while game.status == "playing" and game.steps < maximumSteps do
        local directionName = algorithm.chooseDirection(game, memory, context)
        local result = game:step(directionName)
        if result.died then
            error(algorithmId .. " died for seed " .. seed .. " in " .. edgeMode)
        end
    end
    assertEqual(game.status, "won", algorithmId .. " did not fill the board")
    assertEqual(game.score, game.cols * game.rows - 4, algorithmId .. " ended with the wrong score")
    assertEqual(game:length(), game.cols * game.rows, algorithmId .. " ended with the wrong length")
end

local function trajectory(algorithmId, edgeMode, seed, maximumSteps)
    local game = newAiGame(edgeMode, seed)
    local algorithm = Registry.get(algorithmId)
    local context = algorithmContext(seed)
    local memory = algorithm.reset(game, context) or {}
    local signatures = { game:stateSignature() }
    while game.status == "playing" and game.steps < maximumSteps do
        local directionName = algorithm.chooseDirection(game, memory, context)
        game:step(directionName)
        signatures[#signatures + 1] = game:stateSignature()
    end
    return table.concat(signatures, "\n")
end

test("registry exposes the selected eight algorithms", function()
    local expected = {
        "random-safe",
        "greedy",
        "bfs-shortest",
        "astar-tail-safe",
        "space-scoring",
        "beam-search",
        "hamiltonian",
        "hamiltonian-shortcut",
    }
    assertEqual(#Registry.list, #expected)
    for index, algorithmId in ipairs(expected) do
        assertEqual(Registry.list[index].id, algorithmId)
    end
end)

test("seeded random streams are reproducible and independent", function()
    local first, second = Rng.new("snake-2026", 11), Rng.new("snake-2026", 11)
    local other = Rng.new("snake-2026", 29)
    for _ = 1, 20 do
        assertEqual(first:next(), second:next())
    end
    assertTrue(first:next() ~= other:next(), "separate streams should diverge")

    local foodA, foodB = Rng.new("independent", 11), Rng.new("independent", 11)
    local ai = Rng.new("independent", 29)
    for _ = 1, 100 do
        ai:next()
    end
    assertEqual(foodA:next(), foodB:next(), "AI draws must not advance the food stream")
end)

test("same seed replays the same trajectory", function()
    local first = trajectory("random-safe", "wrap", "replay_seed-01", 120)
    local replay = trajectory("random-safe", "wrap", "replay_seed-01", 120)
    local different = trajectory("random-safe", "wrap", "replay_seed-02", 120)
    assertEqual(first, replay)
    assertTrue(first ~= different, "different seeds should produce a different trajectory")
end)

test("BFS and A* find equally short initial food paths", function()
    local game = newAiGame("walls", "paths")
    local bfs = Search.bfs(game, game.food)
    local astar = Search.astar(game, game.food)
    assertTrue(bfs and astar, "both searches should find the initial food")
    assertEqual(#bfs, #astar)
end)

test("every algorithm returns a safe move without mutating the world", function()
    for _, algorithm in ipairs(Registry.list) do
        local game = newAiGame("walls", "readonly-" .. algorithm.id)
        local context = algorithmContext("readonly-" .. algorithm.id)
        local memory = algorithm.reset(game, context) or {}
        local before = game:stateSignature()
        local directionName = algorithm.chooseDirection(game, memory, context)
        assertEqual(game:stateSignature(), before, algorithm.id .. " mutated the game")
        assertTrue(Game.DIRECTIONS[directionName], algorithm.id .. " returned an unknown direction")
        assertTrue(Grid.isSafe(game, directionName), algorithm.id .. " returned an unsafe initial move")
    end
end)

test("every algorithm remains valid over bounded play", function()
    for _, algorithm in ipairs(Registry.list) do
        for _, edgeMode in ipairs(Constants.EDGE_MODES) do
            local seed = "bounded-" .. edgeMode .. "-" .. algorithm.id
            local game = newAiGame(edgeMode, seed)
            local context = algorithmContext(seed)
            local memory = algorithm.reset(game, context) or {}
            for _ = 1, 80 do
                if game.status ~= "playing" then
                    break
                end
                local legalMoves = Grid.legalDirections(game)
                local before = game:stateSignature()
                local directionName = algorithm.chooseDirection(game, memory, context)
                assertEqual(game:stateSignature(), before, algorithm.id .. " mutated the game")
                assertTrue(Game.DIRECTIONS[directionName], algorithm.id .. " returned an unknown direction")
                if #legalMoves > 0 then
                    assertTrue(Grid.isSafe(game, directionName), algorithm.id .. " ignored a safe move")
                end
                game:step(directionName)
            end
        end
    end
end)

test("hybrid override lasts one step and resets algorithm memory", function()
    local resetCount = 0
    local algorithm = {
        reset = function()
            resetCount = resetCount + 1
            return { generation = resetCount }
        end,
        chooseDirection = function(_, memory)
            assertEqual(memory.generation, resetCount)
            return "right"
        end,
    }
    local session = ControlSession.new(algorithm, { direction = "right" }, Rng.new("hybrid", 29))
    session:queueOverride("up")
    local directionName, intervened = session:chooseDirection({ direction = "right" }, "hybrid", {})
    assertEqual(directionName, "up")
    assertTrue(intervened)
    assertEqual(resetCount, 2)
    assertEqual(session.memory.generation, 2)

    local followingDirection, followingIntervention =
        session:chooseDirection({ direction = "right" }, "hybrid", {})
    assertEqual(followingDirection, "right")
    assertTrue(not followingIntervention, "override should be consumed after one step")
    assertEqual(resetCount, 2)
end)

test("guaranteed algorithms fill both edge modes", function()
    for _, algorithmId in ipairs({ "hamiltonian", "hamiltonian-shortcut" }) do
        for _, edgeMode in ipairs({ "walls", "wrap" }) do
            for seed = 0, 9 do
                simulateToEnd(algorithmId, edgeMode, algorithmId .. "-" .. seed, 4000000)
            end
        end
    end
end)

test("stats round-trip and keep manual records independent from algorithms", function()
    local stats = Stats.new()
    stats:record("walls", "auto", "greedy", {
        score = 42,
        steps = 900,
        elapsed = 12.5,
        speed = 25,
        seed = "score-seed",
        won = true,
    })
    stats:record("walls", "manual", "greedy", { score = 7, won = false })
    stats:record("walls", "manual", "hamiltonian", { score = 9, won = false })
    local restored = Stats.fromJson(stats:toJson())
    local ai = restored:get("walls", "auto", "greedy")
    assertEqual(ai.bestScore, 42)
    assertEqual(ai.bestSteps, 900)
    assertEqual(ai.bestSeed, "score-seed")
    local manual = restored:get("walls", "manual", "random-safe")
    assertEqual(manual.bestScore, 9)
    assertEqual(manual.runs, 2)
end)

test("auto and hybrid records are independent per algorithm", function()
    local stats = Stats.new()
    stats:record("wrap", "auto", "greedy", { score = 10, won = false })
    stats:record("wrap", "hybrid", "greedy", { score = 20, won = false })
    stats:record("wrap", "auto", "hamiltonian", { score = 30, won = false })
    assertEqual(stats:get("wrap", "auto", "greedy").bestScore, 10)
    assertEqual(stats:get("wrap", "hybrid", "greedy").bestScore, 20)
    assertEqual(stats:get("wrap", "auto", "hamiltonian").bestScore, 30)
end)

test("speed presets preserve the original 2x timing curve", function()
    assertEqual(#Constants.SPEED_PRESETS, 15)
    assertEqual(Constants.SPEED_PRESETS[Constants.DEFAULT_SPEED_INDEX], 2)
    assertEqual(Constants.stepInterval(0, 2), 0.145)
    assertEqual(Constants.stepInterval(1000, 2), 0.06)
    for index = 2, #Constants.SPEED_PRESETS do
        assertTrue(Constants.SPEED_PRESETS[index] > Constants.SPEED_PRESETS[index - 1])
    end
    assertEqual(Constants.stepInterval(0, 10000), 0.145 * 2 / 10000)
end)

test("storage writes atomically, backs up corrupt data, and falls back", function()
    local separator = package.config:sub(1, 1)
    local tempDirectory = os.getenv("TEMP") or os.getenv("TMPDIR") or "."
    local temporary = tempDirectory .. separator .. "lua-love2d-snake-test-" .. tostring(os.time())
    local portablePath = temporary .. "-portable.json"
    local userPath = temporary .. "-user.json"
    local missingPath = temporary .. "-missing" .. separator .. "stats.json"

    local storage = Storage.new({ portablePath = portablePath, userPath = userPath })
    assertEqual(storage.mode, "PORTABLE")
    assertTrue(storage:write('{"version":1,"records":{}}\n'))
    assertEqual(storage:read(), '{"version":1,"records":{}}\n')

    local file = assert(io.open(portablePath, "wb"))
    file:write("not json")
    file:close()
    local parsed = pcall(Stats.fromJson, storage:read())
    assertTrue(not parsed, "corrupt JSON should be rejected")
    local backupPath = storage:backupCorrupt()
    assertTrue(backupPath ~= nil, "corrupt data should be moved to a backup")
    local backup = io.open(backupPath, "rb")
    assertTrue(backup ~= nil, "corrupt backup should exist")
    if backup then
        backup:close()
    end

    local fallback = Storage.new({ portablePath = missingPath, userPath = userPath })
    assertEqual(fallback.mode, "USER DIRECTORY")
    assertEqual(fallback.path, userPath)
    assertTrue(fallback:write("fallback"))
    assertEqual(fallback:read(), "fallback")

    os.remove(portablePath)
    os.remove(portablePath .. ".tmp")
    os.remove(portablePath .. ".bak")
    os.remove(backupPath)
    os.remove(userPath)
    os.remove(userPath .. ".tmp")
    os.remove(userPath .. ".bak")
end)

function Suite.run()
    local started = os.clock()
    for _, item in ipairs(tests) do
        item.callback()
        print("PASS " .. item.name)
    end
    print(string.format("Ran %d Lua tests in %.3fs", #tests, os.clock() - started))
    return true
end

if ... == nil then
    Suite.run()
end

return Suite
