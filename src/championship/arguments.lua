local BoardConfig = require("src.board")
local Registry = require("src.ai.algorithm-registry")

local Arguments = {}

local function split(value)
    local result = {}
    for item in tostring(value or ""):gmatch("[^,]+") do
        result[#result + 1] = item:match("^%s*(.-)%s*$")
    end
    return result
end

local function parseSizes(value)
    local result, seen = {}, {}
    for _, item in ipairs(split(value)) do
        local cols, rows, message = BoardConfig.parse(item)
        assert(cols, message or ("INVALID SIZE: " .. item))
        local key = BoardConfig.key(cols, rows)
        assert(not seen[key], "DUPLICATE SIZE: " .. key)
        seen[key] = true
        result[#result + 1] = { cols = cols, rows = rows, key = key }
    end
    assert(#result > 0, "AT LEAST ONE SIZE IS REQUIRED")
    return result
end

local function parseEdges(value)
    local result, seen = {}, {}
    for _, edge in ipairs(split(value)) do
        assert(edge == "walls" or edge == "wrap", "UNKNOWN EDGE MODE: " .. edge)
        assert(not seen[edge], "DUPLICATE EDGE MODE: " .. edge)
        seen[edge] = true
        result[#result + 1] = edge
    end
    assert(#result > 0, "AT LEAST ONE EDGE MODE IS REQUIRED")
    return result
end

local function parseAlgorithms(value)
    if value == "all" then
        local result = {}
        for _, algorithm in ipairs(Registry.list) do
            result[#result + 1] = algorithm.id
        end
        return result
    end
    local result, seen = {}, {}
    for _, algorithmId in ipairs(split(value)) do
        assert(Registry.byId[algorithmId], "UNKNOWN ALGORITHM: " .. algorithmId)
        assert(not seen[algorithmId], "DUPLICATE ALGORITHM: " .. algorithmId)
        seen[algorithmId] = true
        result[#result + 1] = algorithmId
    end
    assert(#result > 0, "AT LEAST ONE ALGORITHM IS REQUIRED")
    return result
end

function Arguments.defaults()
    return {
        sizes = parseSizes("20x14,30x21,40x28"),
        edges = parseEdges("walls,wrap"),
        algorithms = parseAlgorithms("all"),
        runs = 10,
        masterSeed = "snake-championship-v1",
        outputDir = "build/championship",
    }
end

function Arguments.usage()
    return table.concat({
        "Usage: lua5.1 scripts/championship/run-championship.lua [options]",
        "  --sizes 20x14,30x21,40x28",
        "  --edges walls,wrap",
        "  --algorithms all|greedy,hamiltonian",
        "  --runs 10",
        "  --master-seed snake-championship-v1",
        "  --output-dir build/championship",
        "  --merge-manifest build/championship/manifest.txt",
    }, "\n")
end

function Arguments.parse(argv)
    local config = Arguments.defaults()
    local start = 1
    for index, value in ipairs(argv or {}) do
        if value == "--run-championship" then
            start = index + 1
            break
        end
    end
    local index = start
    while argv and index <= #argv do
        local option = argv[index]
        if option == "--help" or option == "-h" then
            config.help = true
            index = index + 1
        else
            local value = argv[index + 1]
            assert(value, "MISSING VALUE FOR " .. tostring(option))
            if option == "--sizes" then
                config.sizes = parseSizes(value)
            elseif option == "--edges" then
                config.edges = parseEdges(value)
            elseif option == "--algorithms" then
                config.algorithms = parseAlgorithms(value)
            elseif option == "--runs" then
                config.runs = tonumber(value)
                assert(config.runs and config.runs == math.floor(config.runs)
                    and config.runs >= 1 and config.runs <= 1000, "RUNS MUST BE AN INTEGER BETWEEN 1 AND 1000")
            elseif option == "--master-seed" then
                assert(value ~= "" and not value:find("[\r\n]"), "MASTER SEED MUST BE ONE NON-EMPTY LINE")
                config.masterSeed = value
            elseif option == "--output-dir" then
                assert(value ~= "", "OUTPUT DIRECTORY MUST NOT BE EMPTY")
                config.outputDir = value
            elseif option == "--merge-manifest" then
                config.mergeManifest = value
            else
                error("UNKNOWN OPTION: " .. tostring(option))
            end
            index = index + 2
        end
    end
    return config
end

return Arguments
