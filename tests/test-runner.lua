local BoardConfig = require("src.board")
local ChampionshipArguments = require("src.championship.arguments")
local ChampionshipReports = require("src.championship.reports")
local ChampionshipRunner = require("src.championship.runner")
local Cycle = require("src.ai.cycle-helpers")
local Constants = require("src.constants")
local ControlSession = require("src.ai.control-session")
local Game = require("src.game")
local GameFactory = require("src.factory")
local Grid = require("src.ai.shared.grid")
local Registry = require("src.ai.algorithm-registry")
local Rng = require("src.rng")
local Search = require("src.ai.shared.search")
local Settings = require("src.settings")
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

local function newAiGame(edgeMode, seed, cols, rows)
    local game = GameFactory.create({
        cols = cols or BoardConfig.DEFAULT_COLS,
        rows = rows or BoardConfig.DEFAULT_ROWS,
        edgeMode = edgeMode,
        controlMode = "auto",
        seed = seed,
    })
    return game
end

local function algorithmContext(seed)
    return {
        aiRng = Rng.new(seed, 29),
    }
end

test("championship CLI scripts compile under Lua 5.1", function()
    local scripts = {
        "scripts/championship/championship-matrix.lua",
        "scripts/championship/run-championship.lua",
    }
    for _, path in ipairs(scripts) do
        local chunk, compileError = loadfile(path)
        if not chunk then
            error(path .. " failed to compile: " .. tostring(compileError))
        end
    end
end)

local function simulateToEnd(algorithmId, edgeMode, seed, maximumSteps, cols, rows)
    local game = newAiGame(edgeMode, seed, cols, rows)
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
    assertTrue(Search.reachable(game, game.food), "food should be reachable")
    assertTrue(Search.reachable(game, game:head()), "the search origin should be reachable")
end)

test("A* tail-safe backs off after rejecting a food route", function()
    local algorithm = Registry.get("astar-tail-safe")
    local game = newAiGame("walls", "astar-backoff")
    local memory = algorithm.reset(game, algorithmContext("astar-backoff"))
    local originalAstar = Search.astar
    local calls = 0
    Search.astar = function()
        calls = calls + 1
        return nil
    end
    local ok, message = pcall(function()
        algorithm.chooseDirection(game, memory)
        algorithm.chooseDirection(game, memory)
        assertEqual(calls, 1, "rejected food routes should not be retried every frame")
        assertTrue(memory.retryStep > game.steps, "retry must be scheduled by game steps")
    end)
    Search.astar = originalAstar
    assertTrue(ok, message)
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
            for seed = 0, 2 do
                simulateToEnd(algorithmId, edgeMode, algorithmId .. "-" .. seed, 4000000)
            end
        end
    end
end)

test("guaranteed algorithms fill horizontal and transposed representative boards", function()
    local sizes = { { 5, 6 }, { 6, 5 }, { 49, 50 }, { 50, 49 } }
    for _, algorithmId in ipairs({ "hamiltonian", "hamiltonian-shortcut" }) do
        for _, size in ipairs(sizes) do
            local cells = size[1] * size[2]
            simulateToEnd(algorithmId, "walls", algorithmId .. "-" .. size[1] .. "x" .. size[2],
                2 * cells * cells, size[1], size[2])
        end
    end
end)

test("Hamiltonian cycles cover every supported board", function()
    for cols = BoardConfig.MIN_SIZE, BoardConfig.MAX_SIZE do
        for rows = BoardConfig.MIN_SIZE, BoardConfig.MAX_SIZE do
            local valid = BoardConfig.validate(cols, rows)
            if valid then
                local cycle = Cycle.get(cols, rows)
                assertEqual(cycle.size, cols * rows)
                local seen = {}
                for index, cell in ipairs(cycle.cells) do
                    assertTrue(cell.x >= 1 and cell.x <= cols and cell.y >= 1 and cell.y <= rows)
                    local key = Game.cellKey(cell.x, cell.y, cols)
                    assertTrue(not seen[key], "cycle contains duplicate cells")
                    seen[key] = true
                    local following = cycle.cells[index % cycle.size + 1]
                    local distance = math.abs(cell.x - following.x) + math.abs(cell.y - following.y)
                    assertEqual(distance, 1, "cycle must close through adjacent cells")
                end
                Cycle.clearCache()
            else
                assertTrue(cols % 2 == 1 and rows % 2 == 1)
            end
        end
    end
end)

test("board settings validate and round-trip", function()
    assertTrue(BoardConfig.validate(5, 6))
    assertTrue(BoardConfig.validate(50, 50))
    local valid, message = BoardConfig.validate(5, 5)
    assertTrue(not valid)
    assertEqual(message, "AT LEAST ONE DIMENSION MUST BE EVEN")
    local restored = Settings.fromJson(Settings.new({ cols = 40, rows = 28 }):toJson())
    assertEqual(restored.data.cols, 40)
    assertEqual(restored.data.rows, 28)
end)

test("game factory keeps every manual starting snake on small boards", function()
    for _, directionName in ipairs({ "up", "right", "down", "left" }) do
        local game = GameFactory.create({ cols = 5, rows = 6, edgeMode = "walls",
            controlMode = "manual", initialDirection = directionName, seed = "small-manual" })
        for _, cell in ipairs(game:bodyCells()) do
            assertTrue(cell.x >= 1 and cell.x <= game.cols and cell.y >= 1 and cell.y <= game.rows)
        end
    end
end)

test("championship arguments reject odd boards", function()
    local ok, message = pcall(ChampionshipArguments.parse, { "--sizes", "5x5" })
    assertTrue(not ok)
    assertTrue(tostring(message):find("AT LEAST ONE DIMENSION MUST BE EVEN", 1, true) ~= nil)
end)

test("championship reports are deterministic", function()
    local config = ChampionshipArguments.parse({ "--sizes", "10x8", "--edges", "walls",
        "--algorithms", "greedy,hamiltonian", "--runs", "1", "--master-seed", "test-report" })
    local games, errors = ChampionshipRunner.run(config)
    assertEqual(#games, 2)
    assertEqual(errors, 0)
    local first = ChampionshipReports.render(ChampionshipReports.build(config, games))
    local second = ChampionshipReports.render(ChampionshipReports.build(config, games))
    assertEqual(first.json, second.json)
    assertEqual(first.csv, second.csv)
    assertEqual(first.markdown, second.markdown)
    assertTrue(first.markdown:find("## Overall Efficiency", 1, true) ~= nil)
    assertTrue(first.markdown:find("## 10x8 / WALLS", 1, true) ~= nil)
end)

test("stats round-trip and keep manual records independent from algorithms", function()
    local stats = Stats.new()
    stats:record(30, 21, "walls", "auto", "greedy", {
        score = 42,
        steps = 900,
        elapsed = 12.5,
        speed = 25,
        seed = "score-seed",
        won = true,
    })
    stats:record(30, 21, "walls", "manual", "greedy", { score = 7, won = false })
    stats:record(30, 21, "walls", "manual", "hamiltonian", { score = 9, won = false })
    local restored = Stats.fromJson(stats:toJson())
    local ai = restored:get(30, 21, "walls", "auto", "greedy")
    assertEqual(ai.bestScore, 42)
    assertEqual(ai.bestSteps, 900)
    assertEqual(ai.bestSeed, "score-seed")
    local manual = restored:get(30, 21, "walls", "manual", "random-safe")
    assertEqual(manual.bestScore, 9)
    assertEqual(manual.runs, 2)
end)

test("auto and hybrid records are independent per algorithm", function()
    local stats = Stats.new()
    stats:record(20, 14, "wrap", "auto", "greedy", { score = 10, won = false })
    stats:record(20, 14, "wrap", "hybrid", "greedy", { score = 20, won = false })
    stats:record(40, 28, "wrap", "auto", "hamiltonian", { score = 30, won = false })
    assertEqual(stats:get(20, 14, "wrap", "auto", "greedy").bestScore, 10)
    assertEqual(stats:get(20, 14, "wrap", "hybrid", "greedy").bestScore, 20)
    assertEqual(stats:get(40, 28, "wrap", "auto", "hamiltonian").bestScore, 30)
    assertEqual(#stats:listDimensions(), 2)
end)

test("stats v1 migrate to the default board", function()
    local legacy = '{"version":1,"records":{"walls|auto|greedy":{"bestScore":12,"runs":1,"wins":0}}}'
    local stats = Stats.fromJson(legacy)
    assertEqual(stats:get(30, 21, "walls", "auto", "greedy").bestScore, 12)
    assertEqual(stats.data.version, 2)
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
