local json = require("src.vendor.json")

local Stats = {}
Stats.__index = Stats
Stats.SCHEMA_VERSION = 1

local function nonNegativeNumber(value, fallback)
    if type(value) == "number" and value >= 0 and value < math.huge then
        return value
    end
    return fallback
end

local function sanitizeRecord(record)
    record = type(record) == "table" and record or {}
    local sanitized = {
        bestScore = math.floor(nonNegativeNumber(record.bestScore, 0)),
        runs = math.floor(nonNegativeNumber(record.runs, 0)),
        wins = math.floor(nonNegativeNumber(record.wins, 0)),
    }
    if nonNegativeNumber(record.bestSteps, nil) then
        sanitized.bestSteps = math.floor(record.bestSteps)
        sanitized.bestTime = nonNegativeNumber(record.bestTime, 0)
        sanitized.bestSpeed = nonNegativeNumber(record.bestSpeed, 1)
        sanitized.bestSeed = type(record.bestSeed) == "string" and record.bestSeed or "unknown"
    end
    sanitized.wins = math.min(sanitized.wins, sanitized.runs)
    return sanitized
end

function Stats.slotKey(edgeMode, controlMode, algorithmId)
    local effectiveAlgorithm = controlMode == "manual" and "player" or algorithmId
    return table.concat({ edgeMode, controlMode, effectiveAlgorithm }, "|")
end

function Stats.new(data)
    local self = setmetatable({ data = { version = Stats.SCHEMA_VERSION, records = {} } }, Stats)
    if type(data) == "table" and data.version == Stats.SCHEMA_VERSION and type(data.records) == "table" then
        for key, record in pairs(data.records) do
            if type(key) == "string" then
                self.data.records[key] = sanitizeRecord(record)
            end
        end
    end
    return self
end

function Stats.fromJson(source)
    local decoded = json.decode(source)
    if type(decoded) ~= "table" or decoded.version ~= Stats.SCHEMA_VERSION then
        error("unsupported stats schema")
    end
    return Stats.new(decoded)
end

function Stats:toJson()
    return json.encode(self.data) .. "\n"
end

function Stats:get(edgeMode, controlMode, algorithmId)
    local key = Stats.slotKey(edgeMode, controlMode, algorithmId)
    if not self.data.records[key] then
        self.data.records[key] = sanitizeRecord(nil)
    end
    return self.data.records[key]
end

function Stats:record(edgeMode, controlMode, algorithmId, outcome)
    local record = self:get(edgeMode, controlMode, algorithmId)
    record.runs = record.runs + 1
    record.bestScore = math.max(record.bestScore, math.floor(outcome.score or 0))
    if outcome.won then
        record.wins = record.wins + 1
        local steps = math.floor(outcome.steps or 0)
        local replacesBest = not record.bestSteps or steps < record.bestSteps
            or (steps == record.bestSteps and (outcome.elapsed or math.huge) < (record.bestTime or math.huge))
        if replacesBest then
            record.bestSteps = steps
            record.bestTime = outcome.elapsed or 0
            record.bestSpeed = outcome.speed or 1
            record.bestSeed = outcome.seed or "unknown"
        end
    end
    return record
end

function Stats:reset()
    self.data = { version = Stats.SCHEMA_VERSION, records = {} }
end

return Stats
