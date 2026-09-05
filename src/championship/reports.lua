local json = require("src.vendor.json")

local Reports = {}
Reports.SCHEMA_VERSION = 1

local function isArray(value)
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then
            return false
        end
        count = math.max(count, key)
    end
    for index = 1, count do
        if value[index] == nil then return false end
    end
    return true, count
end

local function escape(value)
    return value:gsub("[\\\"%z\1-\31]", function(character)
        local replacements = { ['\\'] = '\\\\', ['"'] = '\\"', ['\b'] = '\\b', ['\f'] = '\\f',
            ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
        return replacements[character] or string.format("\\u%04x", character:byte())
    end)
end

local function canonicalJson(value)
    local kind = type(value)
    if kind == "nil" then return "null" end
    if kind == "boolean" then return value and "true" or "false" end
    if kind == "number" then
        assert(value == value and value > -math.huge and value < math.huge, "cannot encode non-finite number")
        return value == math.floor(value) and string.format("%.0f", value) or string.format("%.12g", value)
    end
    if kind == "string" then return '"' .. escape(value) .. '"' end
    assert(kind == "table", "unsupported JSON value: " .. kind)
    local array, count = isArray(value)
    if array then
        local items = {}
        for index = 1, count do items[index] = canonicalJson(value[index]) end
        return "[" .. table.concat(items, ",") .. "]"
    end
    local keys = {}
    for key in pairs(value) do
        assert(type(key) == "string", "JSON object keys must be strings")
        keys[#keys + 1] = key
    end
    table.sort(keys)
    local items = {}
    for index, key in ipairs(keys) do
        items[index] = canonicalJson(key) .. ":" .. canonicalJson(value[key])
    end
    return "{" .. table.concat(items, ",") .. "}"
end

local function median(values)
    if #values == 0 then return nil end
    table.sort(values)
    local middle = math.floor(#values / 2) + 1
    return #values % 2 == 1 and values[middle] or (values[middle - 1] + values[middle]) / 2
end

local function aggregate(games, normalizedEfficiency)
    local byAlgorithm = {}
    for _, game in ipairs(games) do
        local item = byAlgorithm[game.algorithm]
        if not item then
            item = { algorithm = game.algorithm, runs = 0, wins = 0, timeouts = 0,
                collisions = 0, errors = 0, fillTotal = 0, efficiencyValues = {} }
            byAlgorithm[game.algorithm] = item
        end
        item.runs = item.runs + 1
        item.fillTotal = item.fillTotal + game.fillRate
        item.wins = item.wins + (game.outcome == "won" and 1 or 0)
        item.timeouts = item.timeouts + (game.outcome == "timeout" and 1 or 0)
        item.collisions = item.collisions + (game.outcome == "collision" and 1 or 0)
        item.errors = item.errors + (game.outcome == "error" and 1 or 0)
        if game.outcome == "won" then
            item.efficiencyValues[#item.efficiencyValues + 1] = normalizedEfficiency
                and game.stepsPerFood or game.steps
        end
    end
    local reliability, efficiency = {}, {}
    for _, item in pairs(byAlgorithm) do
        item.completionRate = item.wins / item.runs
        item.averageFillRate = item.fillTotal / item.runs
        local sum = 0
        for _, value in ipairs(item.efficiencyValues) do sum = sum + value end
        if item.wins > 0 then
            efficiency[#efficiency + 1] = {
                algorithm = item.algorithm,
                wins = item.wins,
                median = median(item.efficiencyValues),
                mean = sum / #item.efficiencyValues,
            }
        end
        item.efficiencyValues, item.fillTotal = nil, nil
        reliability[#reliability + 1] = item
    end
    table.sort(reliability, function(left, right)
        if left.completionRate ~= right.completionRate then return left.completionRate > right.completionRate end
        if left.averageFillRate ~= right.averageFillRate then return left.averageFillRate > right.averageFillRate end
        if left.timeouts ~= right.timeouts then return left.timeouts < right.timeouts end
        return left.algorithm < right.algorithm
    end)
    table.sort(efficiency, function(left, right)
        if left.median ~= right.median then return left.median < right.median end
        if left.mean ~= right.mean then return left.mean < right.mean end
        return left.algorithm < right.algorithm
    end)
    local function assignRanks(items, fields)
        local rank, previous
        for index, item in ipairs(items) do
            local signature = {}
            for _, field in ipairs(fields) do signature[#signature + 1] = string.format("%.12g", item[field]) end
            signature = table.concat(signature, "|")
            if signature ~= previous then rank = index end
            item.rank, previous = rank, signature
        end
    end
    assignRanks(reliability, { "completionRate", "averageFillRate", "timeouts" })
    assignRanks(efficiency, { "median", "mean" })
    return { reliability = reliability, efficiency = efficiency }
end

local function buildRankings(games)
    local scenarios, grouped, order = {}, {}, {}
    for _, game in ipairs(games) do
        local key = game.size .. "|" .. game.edge
        if not grouped[key] then
            grouped[key] = {}
            order[#order + 1] = { key = key, size = game.size, edge = game.edge }
        end
        grouped[key][#grouped[key] + 1] = game
    end
    table.sort(order, function(left, right) return left.key < right.key end)
    for _, scenario in ipairs(order) do
        local ranking = aggregate(grouped[scenario.key], false)
        ranking.size, ranking.edge = scenario.size, scenario.edge
        scenarios[#scenarios + 1] = ranking
    end
    return { overall = aggregate(games, true), scenarios = scenarios }
end

local function csvEscape(value)
    value = tostring(value or "")
    if value:find('[,"\r\n]') then return '"' .. value:gsub('"', '""') .. '"' end
    return value
end

local function renderCsv(games)
    local lines = { "size,cols,rows,edge,algorithm,run,seed,outcome,timeout_reason,score,final_length,total_cells,fill_rate,steps,step_cap,stagnation_cap,steps_per_food" }
    for _, game in ipairs(games) do
        local values = { game.size, game.cols, game.rows, game.edge, game.algorithm, game.run, game.seed,
            game.outcome, game.timeoutReason or "", game.score, game.finalLength, game.totalCells,
            string.format("%.6f", game.fillRate), game.steps, game.stepCap, game.stagnationCap,
            game.stepsPerFood and string.format("%.6f", game.stepsPerFood) or "" }
        for index, value in ipairs(values) do values[index] = csvEscape(value) end
        lines[#lines + 1] = table.concat(values, ",")
    end
    return table.concat(lines, "\n") .. "\n"
end

local function reliabilityTable(lines, ranking)
    lines[#lines + 1] = "| Rank | Algorithm | Wins/Runs | Completion | Avg fill | Timeouts | Collisions | Errors |"
    lines[#lines + 1] = "| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |"
    for _, item in ipairs(ranking.reliability) do
        lines[#lines + 1] = string.format("| %d | %s | %d/%d | %.2f%% | %.2f%% | %d | %d | %d |",
            item.rank, item.algorithm, item.wins, item.runs, item.completionRate * 100,
            item.averageFillRate * 100, item.timeouts, item.collisions, item.errors)
    end
end

local function efficiencyTable(lines, ranking, normalized)
    lines[#lines + 1] = normalized
        and "| Rank | Algorithm | Wins | Median steps/food | Mean steps/food |"
        or "| Rank | Algorithm | Wins | Median steps | Mean steps |"
    lines[#lines + 1] = "| ---: | --- | ---: | ---: | ---: |"
    for _, item in ipairs(ranking.efficiency) do
        lines[#lines + 1] = string.format("| %d | %s | %d | %.3f | %.3f |",
            item.rank, item.algorithm, item.wins, item.median, item.mean)
    end
end

local function renderMarkdown(document)
    local lines = { "# AI Championship", "", "Deterministic AUTO results. Wall-clock timing is intentionally excluded.",
        "", "## Overall Reliability", "" }
    reliabilityTable(lines, document.rankings.overall)
    lines[#lines + 1] = ""
    lines[#lines + 1] = "## Overall Efficiency"
    lines[#lines + 1] = ""
    efficiencyTable(lines, document.rankings.overall, true)
    for _, scenario in ipairs(document.rankings.scenarios) do
        lines[#lines + 1] = ""
        lines[#lines + 1] = "## " .. scenario.size .. " / " .. string.upper(scenario.edge)
        lines[#lines + 1] = ""
        reliabilityTable(lines, scenario)
        lines[#lines + 1] = ""
        efficiencyTable(lines, scenario, false)
    end
    return table.concat(lines, "\n") .. "\n"
end

local function ensureDirectory(path)
    assert(not path:find('["\r\n]'), "output directory contains unsupported characters")
    local command
    if package.config:sub(1, 1) == "\\" then
        command = 'if not exist "' .. path .. '" mkdir "' .. path .. '"'
    else
        command = "mkdir -p -- '" .. path:gsub("'", "'\\''") .. "'"
    end
    local first, _, third = os.execute(command)
    assert(first == true or first == 0 or third == 0, "could not create output directory")
end

local function writeFile(path, content)
    local file = assert(io.open(path, "wb"))
    assert(file:write(content))
    file:close()
end

function Reports.build(config, games)
    return {
        schemaVersion = Reports.SCHEMA_VERSION,
        kind = "lua-love2d-snake-championship",
        config = {
            sizes = config.sizes,
            edges = config.edges,
            algorithms = config.algorithms,
            runs = config.runs,
            masterSeed = config.masterSeed,
            stepCap = "2*cells^2",
            stagnationCap = "cells without food",
        },
        games = games,
        rankings = buildRankings(games),
    }
end

function Reports.render(document)
    return {
        json = canonicalJson(document) .. "\n",
        csv = renderCsv(document.games),
        markdown = renderMarkdown(document),
    }
end

function Reports.write(outputDir, document)
    ensureDirectory(outputDir)
    local separator = package.config:sub(1, 1)
    local rendered = Reports.render(document)
    writeFile(outputDir .. separator .. "championship.json", rendered.json)
    writeFile(outputDir .. separator .. "championship.csv", rendered.csv)
    writeFile(outputDir .. separator .. "championship.md", rendered.markdown)
    return rendered
end

function Reports.mergeManifest(path)
    local manifest = assert(io.open(path, "rb"))
    local games, firstConfig = {}, nil
    for line in manifest:lines() do
        line = line:gsub("\r$", "")
        if line ~= "" then
            local file = assert(io.open(line, "rb"))
            local document = json.decode(file:read("*a"))
            file:close()
            assert(document.schemaVersion == Reports.SCHEMA_VERSION
                and document.kind == "lua-love2d-snake-championship", "unsupported championship shard")
            firstConfig = firstConfig or document.config
            for _, game in ipairs(document.games) do games[#games + 1] = game end
        end
    end
    manifest:close()
    assert(firstConfig and #games > 0, "merge manifest contains no championship reports")
    table.sort(games, function(left, right)
        local leftKey = table.concat({ left.size, left.edge, left.algorithm, string.format("%04d", left.run) }, "|")
        local rightKey = table.concat({ right.size, right.edge, right.algorithm, string.format("%04d", right.run) }, "|")
        return leftKey < rightKey
    end)
    local sizes, edges, algorithms = {}, {}, {}
    local sizeSeen, edgeSeen, algorithmSeen = {}, {}, {}
    for _, game in ipairs(games) do
        if not sizeSeen[game.size] then
            sizeSeen[game.size] = true
            sizes[#sizes + 1] = { cols = game.cols, rows = game.rows, key = game.size }
        end
        if not edgeSeen[game.edge] then edgeSeen[game.edge], edges[#edges + 1] = true, game.edge end
        if not algorithmSeen[game.algorithm] then
            algorithmSeen[game.algorithm], algorithms[#algorithms + 1] = true, game.algorithm
        end
    end
    return Reports.build({ sizes = sizes, edges = edges, algorithms = algorithms,
        runs = firstConfig.runs, masterSeed = firstConfig.masterSeed }, games)
end

return Reports
