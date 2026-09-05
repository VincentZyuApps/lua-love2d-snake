local BoardConfig = require("src.board")
local Constants = require("src.constants")
local ControlSession = require("src.ai.control-session")
local GameFactory = require("src.factory")
local Game = require("src.game")
local Registry = require("src.ai.algorithm-registry")
local Settings = require("src.settings")
local Stats = require("src.stats")
local Storage = require("src.storage")

local BASE_W, BASE_H = Constants.BASE_WIDTH, Constants.BASE_HEIGHT
local CONTENT_X, CONTENT_Y = Constants.BOARD_AREA_X, Constants.BOARD_AREA_Y
local CONTENT_W, CONTENT_H = Constants.BOARD_AREA_WIDTH, Constants.BOARD_AREA_HEIGHT
local EDGE_X, CONTROL_X, SPEED_X = 42, 278, 682
local SELECTOR_Y, SELECTOR_H = 94, 30
local EDGE_W, CONTROL_W, SPEED_W = 220, 390, 236
local ALGORITHM_X, ALGORITHM_Y, ALGORITHM_W, ALGORITHM_H = 278, 20, 390, 64
local SCORE_X, BEST_X = 682, 808

local colors = {
    background = { 13, 22, 29 },
    panel = { 22, 37, 42 },
    grid = { 35, 57, 58 },
    border = { 89, 128, 116 },
    text = { 236, 244, 235 },
    muted = { 157, 182, 172 },
    snake = { 117, 226, 135 },
    snakeDark = { 58, 155, 105 },
    food = { 247, 105, 87 },
    gold = { 245, 200, 82 },
    cyan = { 91, 205, 232 },
}

local keyDirections = {
    w = "up", up = "up",
    s = "down", down = "down",
    a = "left", left = "left",
    d = "right", right = "right",
}

local edgeOptions = {
    { id = "walls", label = "WALLS", color = colors.gold },
    { id = "wrap", label = "WRAP", color = colors.snake },
}

local controlOptions = {
    { id = "manual", label = "MANUAL", color = colors.gold },
    { id = "auto", label = "AUTO", color = colors.snake },
    { id = "hybrid", label = "HYBRID", color = colors.cyan },
}

local app = {
    edgeMode = "walls",
    controlMode = "manual",
    algorithmId = "hamiltonian",
    speedIndex = Constants.DEFAULT_SPEED_INDEX,
    state = "title",
    focused = true,
    inputEvent = "WAITING FOR INPUT",
    cols = BoardConfig.DEFAULT_COLS,
    rows = BoardConfig.DEFAULT_ROWS,
}

local function updateBoardLayout()
    app.cell = math.floor(math.min(CONTENT_W / app.cols, CONTENT_H / app.rows))
    app.boardWidth, app.boardHeight = app.cols * app.cell, app.rows * app.cell
    app.boardX = CONTENT_X + math.floor((CONTENT_W - app.boardWidth) / 2)
    app.boardY = CONTENT_Y + math.floor((CONTENT_H - app.boardHeight) / 2)
end

local function setColor(color, alpha)
    love.graphics.setColor(color[1] / 255, color[2] / 255, color[3] / 255, alpha or 1)
end

local function currentSpeed()
    return Constants.SPEED_PRESETS[app.speedIndex]
end

local function randomSeedText()
    return string.format("%08x", love.math.random(0, 0x7fffffff))
end

local function sanitizeSeed(value)
    local sanitized = tostring(value or ""):gsub("[^%w_-]", "")
    return sanitized:sub(1, 32)
end

local function displaySeed(value, maximum)
    maximum = maximum or 20
    if #value <= maximum then
        return value
    end
    return value:sub(1, maximum - 3) .. "..."
end

local function saveStats()
    local ok, errorMessage = app.statsStorage:write(app.stats:toJson())
    if not ok and app.statsStorage.mode == "PORTABLE" and app.statsStorage.switchToUserDirectory then
        app.statsStorage:switchToUserDirectory()
        ok, errorMessage = app.statsStorage:write(app.stats:toJson())
    end
    app.saveNotice = ok and nil or ("SAVE FAILED: " .. tostring(errorMessage))
    return ok
end

local function loadStats()
    app.statsStorage = Storage.new()
    local source = app.statsStorage:read()
    if not source then
        app.stats = Stats.new()
        return
    end
    local ok, result = pcall(Stats.fromJson, source)
    if ok then
        app.stats = result
        if result.migrated then
            result.migrated = false
            saveStats()
        end
    else
        local backupPath = app.statsStorage:backupCorrupt()
        app.stats = Stats.new()
        app.saveNotice = backupPath and "INVALID STATS WERE BACKED UP" or "INVALID STATS; BACKUP FAILED"
    end
end

local function saveSettings()
    app.settings:setBoardSize(app.cols, app.rows)
    local ok, errorMessage = app.settingsStorage:write(app.settings:toJson())
    if not ok and app.settingsStorage.mode == "PORTABLE" then
        app.settingsStorage:switchToUserDirectory()
        ok, errorMessage = app.settingsStorage:write(app.settings:toJson())
    end
    app.saveNotice = ok and nil or ("SAVE FAILED: " .. tostring(errorMessage))
    return ok
end

local function loadSettings()
    app.settingsStorage = Storage.new({ fileName = "lua-love2d-snake-settings.json" })
    local source = app.settingsStorage:read()
    if source then
        local ok, result = pcall(Settings.fromJson, source)
        if ok then
            app.settings = result
        else
            local backupPath = app.settingsStorage:backupCorrupt()
            app.settings = Settings.new()
            app.saveNotice = backupPath and "INVALID SETTINGS WERE BACKED UP" or "INVALID SETTINGS; BACKUP FAILED"
        end
    else
        app.settings = Settings.new()
    end
    app.cols, app.rows = app.settings.data.cols, app.settings.data.rows
    updateBoardLayout()
end

local function resetPerformance()
    app.performance = {
        elapsed = 0,
        ticks = 0,
        aiSeconds = 0,
        aiDecisions = 0,
        actualTps = 0,
        aiMspt = 0,
    }
end

local function resetEngine(initialDirection)
    updateBoardLayout()
    app.engine, app.aiRng, app.foodRng = GameFactory.create({
        cols = app.cols,
        rows = app.rows,
        edgeMode = app.edgeMode,
        controlMode = app.controlMode,
        initialDirection = initialDirection or "right",
        seed = app.seedText,
    })
    local directionName = app.engine.direction
    app.algorithm = Registry.get(app.algorithmId)
    app.controlSession = ControlSession.new(app.algorithm, app.engine, app.aiRng)
    app.queuedDirection = directionName
    app.turnQueued = false
    app.hybridIntervened = false
    app.logicTimer = 0
    app.stepInterval = Constants.stepInterval(0, currentSpeed())
    app.runElapsed = 0
    app.pulse = 0
    resetPerformance()
end

local function beginRun(initialDirection, newSeed)
    if newSeed then
        app.seedText = randomSeedText()
    end
    resetEngine(initialDirection)
    app.state = "playing"
    app.pausedForFocus = false
end

local function isBetweenRounds()
    return app.state == "title" or app.state == "over" or app.state == "won"
end

local function activeRecord()
    return app.stats:get(app.cols, app.rows, app.edgeMode, app.controlMode, app.algorithmId)
end

local function finishRun(won)
    app.stats:record(app.cols, app.rows, app.edgeMode, app.controlMode, app.algorithmId, {
        score = app.engine.score,
        steps = app.engine.steps,
        elapsed = app.runElapsed,
        speed = currentSpeed(),
        seed = app.seedText,
        won = won,
    })
    saveStats()
    app.state = won and "won" or "over"
end

local function currentSetting(kind)
    if kind == "edge" then
        return app.edgeMode
    elseif kind == "control" then
        return app.controlMode
    elseif kind == "algorithm" then
        return app.algorithmId
    elseif kind == "size" then
        return BoardConfig.key(app.cols, app.rows)
    end
    return nil
end

local function applySetting(kind, value)
    if kind == "edge" then
        app.edgeMode = value
    elseif kind == "control" then
        app.controlMode = value
    elseif kind == "algorithm" then
        app.algorithmId = value
    elseif kind == "seed" then
        app.seedText = value
    elseif kind == "size" then
        app.cols, app.rows = value.cols, value.rows
        updateBoardLayout()
        saveSettings()
    end
end

local function requestChange(kind, value)
    local comparable = kind == "size" and BoardConfig.key(value.cols, value.rows) or value
    if kind ~= "seed" and currentSetting(kind) == comparable then
        return true
    end
    if isBetweenRounds() then
        applySetting(kind, value)
        resetEngine()
        app.state = "title"
    else
        app.pendingChange = { kind = kind, value = value }
        app.stateBeforePrompt = app.state
        app.state = "confirm-change"
    end
    return true
end

local function confirmChange()
    if app.state ~= "confirm-change" or not app.pendingChange then
        return
    end
    local change = app.pendingChange
    if change.kind ~= "replay" then
        applySetting(change.kind, change.value)
    end
    app.pendingChange = nil
    app.stateBeforePrompt = nil
    beginRun(nil, false)
end

local function cancelChange()
    if app.state ~= "confirm-change" then
        return
    end
    app.state = app.stateBeforePrompt or "playing"
    app.pendingChange = nil
    app.stateBeforePrompt = nil
end

local function requestReplay()
    if isBetweenRounds() then
        beginRun(nil, false)
    elseif app.state == "playing" or app.state == "paused" then
        app.pendingChange = { kind = "replay", value = app.seedText }
        app.stateBeforePrompt = app.state
        app.state = "confirm-change"
    end
end

local function setSpeedIndex(index)
    local nextIndex = math.max(1, math.min(#Constants.SPEED_PRESETS, index))
    if nextIndex == app.speedIndex then
        return false
    end
    local previousInterval = app.stepInterval
    local progress = previousInterval > 0 and math.min(app.logicTimer / previousInterval, 1) or 0
    app.speedIndex = nextIndex
    app.stepInterval = Constants.stepInterval(app.engine.score, currentSpeed())
    app.logicTimer = progress * app.stepInterval
    return true
end

local function changeSpeed(delta)
    if app.state == "confirm-change" or app.state == "confirm-reset"
        or app.state == "seed-input" or app.state == "size-input" then
        return false
    end
    return setSpeedIndex(app.speedIndex + delta)
end

local function cycleEdge()
    requestChange("edge", app.edgeMode == "walls" and "wrap" or "walls")
end

local function cycleControl()
    for index, option in ipairs(controlOptions) do
        if option.id == app.controlMode then
            requestChange("control", controlOptions[index % #controlOptions + 1].id)
            return
        end
    end
end

local function cycleAlgorithm(delta)
    local algorithm = Registry.next(app.algorithmId, delta)
    requestChange("algorithm", algorithm.id)
end

local function openModal(state)
    if app.state == "confirm-change" or app.state == "confirm-reset"
        or app.state == "seed-input" or app.state == "size-input" then
        return
    end
    app.stateBeforeModal = app.state
    app.state = state
end

local function closeModal()
    local returnState = app.stateBeforeModal or "title"
    if returnState == "playing" and not app.focused then
        returnState = "paused"
        app.pausedForFocus = true
    elseif returnState == "paused" and app.focused and app.pausedForFocus then
        returnState = "playing"
        app.pausedForFocus = false
    end
    app.state = returnState
    app.stateBeforeModal = nil
end

local function openSeedInput()
    if app.state == "seed-input" then
        return
    end
    app.seedBuffer = ""
    openModal("seed-input")
end

local function submitSeed()
    local value = sanitizeSeed(app.seedBuffer)
    if value == "" then
        value = randomSeedText()
    end
    local returnState = app.stateBeforeModal or "title"
    app.state = returnState
    app.stateBeforeModal = nil
    requestChange("seed", value)
end

local function openSizeInput()
    app.sizeWidthBuffer = tostring(app.cols)
    app.sizeHeightBuffer = tostring(app.rows)
    app.sizeField = "width"
    app.sizeError = nil
    openModal("size-input")
end

local function submitSize(cols, rows)
    cols = cols or tonumber(app.sizeWidthBuffer)
    rows = rows or tonumber(app.sizeHeightBuffer)
    local valid, message = BoardConfig.validate(cols, rows)
    if not valid then
        app.sizeError = message
        return false
    end
    local returnState = app.stateBeforeModal or "title"
    app.state, app.stateBeforeModal = returnState, nil
    requestChange("size", { cols = cols, rows = rows })
    return true
end

local function refreshLeaderboardDimensions()
    local byKey = {}
    local currentKey = BoardConfig.key(app.cols, app.rows)
    byKey[currentKey] = { cols = app.cols, rows = app.rows, key = currentKey }
    for _, dimensions in ipairs(app.stats:listDimensions()) do
        byKey[dimensions.key] = dimensions
    end
    app.leaderboardDimensions = {}
    for _, dimensions in pairs(byKey) do
        app.leaderboardDimensions[#app.leaderboardDimensions + 1] = dimensions
    end
    table.sort(app.leaderboardDimensions, function(left, right)
        return left.cols * left.rows < right.cols * right.rows
            or left.cols * left.rows == right.cols * right.rows and left.key < right.key
    end)
    app.leaderboardSizeIndex = 1
    for index, dimensions in ipairs(app.leaderboardDimensions) do
        if dimensions.key == currentKey then
            app.leaderboardSizeIndex = index
            break
        end
    end
end

local function cycleLeaderboardSize(delta)
    local count = #app.leaderboardDimensions
    app.leaderboardSizeIndex = ((app.leaderboardSizeIndex - 1 + delta) % count) + 1
end

local function openLeaderboard()
    app.leaderboardEdge = app.edgeMode
    app.leaderboardControl = app.controlMode
    refreshLeaderboardDimensions()
    openModal("leaderboard")
end

local function requestStatsReset()
    if app.state ~= "leaderboard" then
        return
    end
    app.state = "confirm-reset"
end

local function confirmStatsReset()
    app.stats:reset()
    saveStats()
    refreshLeaderboardDimensions()
    app.state = "leaderboard"
end

local function queueDirection(directionName)
    if app.controlMode == "auto" then
        app.inputEvent = "AUTO  DIRECTION IGNORED"
        return
    end
    if app.state == "title" or app.state == "over" or app.state == "won" then
        local newSeed = app.state ~= "title"
        if app.controlMode == "manual" then
            beginRun(directionName, newSeed)
        else
            beginRun(nil, newSeed)
            if directionName ~= Game.DIRECTIONS[app.engine.direction].opposite then
                app.controlSession:queueOverride(directionName)
            end
        end
        return
    end
    if app.state ~= "playing" or directionName == Game.DIRECTIONS[app.engine.direction].opposite then
        return
    end
    if app.controlMode == "manual" then
        if not app.turnQueued then
            app.queuedDirection = directionName
            app.turnQueued = true
        end
    else
        app.controlSession:queueOverride(directionName)
    end
end

local function chooseDirection()
    if app.controlMode == "manual" then
        app.turnQueued = false
        return app.queuedDirection, 0
    end

    local started = love.timer.getTime()
    local directionName, intervened = app.controlSession:chooseDirection(app.engine, app.controlMode, {
        aiRng = app.aiRng,
    })
    local aiSeconds = love.timer.getTime() - started
    if intervened then
        app.hybridIntervened = true
    end
    app.queuedDirection = directionName
    return directionName, aiSeconds
end

local function updatePerformance(dt)
    local performance = app.performance
    performance.elapsed = performance.elapsed + dt
    if performance.elapsed >= 1 then
        performance.actualTps = performance.ticks / performance.elapsed
        performance.aiMspt = performance.aiDecisions > 0
            and performance.aiSeconds * 1000 / performance.aiDecisions or 0
        performance.elapsed = 0
        performance.ticks = 0
        performance.aiSeconds = 0
        performance.aiDecisions = 0
    end
end

local function scaleTransform()
    local width, height = love.graphics.getDimensions()
    local scale = math.min(width / BASE_W, height / BASE_H)
    return scale, (width - BASE_W * scale) / 2, (height - BASE_H * scale) / 2
end

local function cellToPixel(cell)
    return app.boardX + (cell.x - 1) * app.cell, app.boardY + (cell.y - 1) * app.cell
end

local function pointInRect(x, y, rectX, rectY, width, height)
    return x >= rectX and x <= rectX + width and y >= rectY and y <= rectY + height
end

local function drawBackground()
    setColor(colors.background)
    love.graphics.rectangle("fill", 0, 0, BASE_W, BASE_H)
    setColor({ 25, 47, 48 })
    for x = 0, BASE_W, 48 do
        love.graphics.line(x, 0, x - 250, BASE_H)
    end
    setColor({ 16, 33, 39 }, 0.9)
    love.graphics.rectangle("fill", 0, 0, BASE_W, 128)
    love.graphics.rectangle("fill", 0, BASE_H - 52, BASE_W, 52)
end

local function drawBoard()
    setColor(colors.panel)
    love.graphics.rectangle("fill", app.boardX - 8, app.boardY - 8, app.boardWidth + 16, app.boardHeight + 16, 6, 6)
    setColor(colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", app.boardX - 1, app.boardY - 1, app.boardWidth + 2, app.boardHeight + 2)
    love.graphics.setLineWidth(1)
    setColor(colors.grid, 0.42)
    for x = 0, app.cols do
        love.graphics.line(app.boardX + x * app.cell, app.boardY,
            app.boardX + x * app.cell, app.boardY + app.boardHeight)
    end
    for y = 0, app.rows do
        love.graphics.line(app.boardX, app.boardY + y * app.cell,
            app.boardX + app.boardWidth, app.boardY + y * app.cell)
    end
end

local function drawFood()
    if not app.engine.food then
        return
    end
    local x, y = cellToPixel(app.engine.food)
    local wobble = math.sin(love.timer.getTime() * 5) * math.min(1.2, app.cell * 0.06)
    local radius = math.max(2, app.cell * 0.32)
    setColor(colors.food)
    love.graphics.circle("fill", x + app.cell / 2, y + app.cell / 2 + wobble, radius)
    setColor(colors.gold)
    love.graphics.rectangle("fill", x + app.cell * 0.46, y + app.cell * 0.08 + wobble,
        math.max(1, app.cell * 0.12), math.max(2, app.cell * 0.2))
    setColor(colors.text, 0.55)
    love.graphics.circle("fill", x + app.cell * 0.38, y + app.cell * 0.38 + wobble,
        math.max(1, app.cell * 0.08))
end

local function drawSnake()
    for index = app.engine.last, app.engine.first, -1 do
        local segment = app.engine.segments[index]
        local x, y = cellToPixel(segment)
        local isHead = index == app.engine.first
        local inset = math.max(1, math.floor(app.cell * (isHead and 0.08 or 0.12)))
        setColor(isHead and colors.snake or colors.snakeDark)
        love.graphics.rectangle("fill", x + inset, y + inset, app.cell - inset * 2, app.cell - inset * 2,
            math.min(5, app.cell * 0.2), math.min(5, app.cell * 0.2))
    end

    local head = app.engine:head()
    local x, y = cellToPixel(head)
    local direction = Game.DIRECTIONS[app.engine.direction]
    local eyeOffsetX = direction.x * app.cell * 0.14
    local eyeOffsetY = direction.y * app.cell * 0.14
    local eyeRadius = math.max(1, app.cell * 0.07)
    setColor(colors.background)
    love.graphics.circle("fill", x + app.cell * 0.34 + eyeOffsetX, y + app.cell * 0.34 + eyeOffsetY, eyeRadius)
    love.graphics.circle("fill", x + app.cell * 0.66 + eyeOffsetX, y + app.cell * 0.66 + eyeOffsetY, eyeRadius)
end

local function drawStatBox(label, value, x, accent, valueColor)
    local y, width, height = 20, 110, 64
    setColor(colors.panel, 0.96)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)
    setColor(colors.border, 0.78)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 5, 5)
    setColor(accent)
    love.graphics.rectangle("fill", x, y, 4, height, 3, 3)
    setColor(colors.muted)
    love.graphics.print(label, x + 14, y + 9)
    setColor(valueColor)
    love.graphics.printf(tostring(value), x + 14, y + 32, width - 26, "right")
end

local function selectorSegmentBounds(x, width, labelWidth, count, index)
    local segmentsX = x + labelWidth
    local segmentWidth = (width - labelWidth - 4) / count
    return segmentsX + (index - 1) * segmentWidth, SELECTOR_Y + 3, segmentWidth, SELECTOR_H - 6
end

local function drawSelector(label, options, selectedId, x, width, labelWidth)
    setColor(colors.panel, 0.96)
    love.graphics.rectangle("fill", x, SELECTOR_Y, width, SELECTOR_H, 4, 4)
    setColor(colors.border, 0.78)
    love.graphics.rectangle("line", x + 0.5, SELECTOR_Y + 0.5, width - 1, SELECTOR_H - 1, 4, 4)
    setColor(colors.muted)
    love.graphics.print(label, x + 8, SELECTOR_Y + 8)
    for index, option in ipairs(options) do
        local segmentX, segmentY, segmentWidth, segmentHeight =
            selectorSegmentBounds(x, width, labelWidth, #options, index)
        local selected = option.id == selectedId
        setColor(selected and option.color or colors.background, selected and 0.9 or 0.72)
        love.graphics.rectangle("fill", segmentX, segmentY, segmentWidth, segmentHeight, 3, 3)
        setColor(selected and option.color or colors.border, selected and 1 or 0.55)
        love.graphics.rectangle("line", segmentX + 0.5, segmentY + 0.5, segmentWidth - 1, segmentHeight - 1, 3, 3)
        setColor(selected and colors.background or colors.muted)
        love.graphics.printf(option.label, segmentX, segmentY + 5, segmentWidth, "center")
    end
end

local function optionAtPoint(options, x, y, selectorX, selectorWidth, labelWidth)
    for index, option in ipairs(options) do
        local segmentX, segmentY, width, height =
            selectorSegmentBounds(selectorX, selectorWidth, labelWidth, #options, index)
        if pointInRect(x, y, segmentX, segmentY, width, height) then
            return option.id
        end
    end
end

local function speedButtonBounds(direction)
    local buttonWidth = 30
    if direction < 0 then
        return SPEED_X + 62, SELECTOR_Y + 3, buttonWidth, SELECTOR_H - 6
    end
    return SPEED_X + SPEED_W - buttonWidth - 4, SELECTOR_Y + 3, buttonWidth, SELECTOR_H - 6
end

local function drawSpeedSelector()
    setColor(colors.panel, 0.96)
    love.graphics.rectangle("fill", SPEED_X, SELECTOR_Y, SPEED_W, SELECTOR_H, 4, 4)
    setColor(colors.border, 0.78)
    love.graphics.rectangle("line", SPEED_X + 0.5, SELECTOR_Y + 0.5, SPEED_W - 1, SELECTOR_H - 1, 4, 4)
    setColor(colors.muted)
    love.graphics.print("SPEED", SPEED_X + 8, SELECTOR_Y + 8)
    for _, direction in ipairs({ -1, 1 }) do
        local x, y, width, height = speedButtonBounds(direction)
        local enabled = direction < 0 and app.speedIndex > 1
            or direction > 0 and app.speedIndex < #Constants.SPEED_PRESETS
        setColor(colors.background, 0.72)
        love.graphics.rectangle("fill", x, y, width, height, 3, 3)
        setColor(enabled and colors.cyan or colors.border, enabled and 1 or 0.45)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 3, 3)
        setColor(enabled and colors.text or colors.muted, enabled and 1 or 0.45)
        love.graphics.printf(direction < 0 and "<" or ">", x, y + 5, width, "center")
    end
    local leftX, _, leftWidth = speedButtonBounds(-1)
    local rightX = speedButtonBounds(1)
    setColor(colors.cyan)
    love.graphics.printf(tostring(currentSpeed()) .. "x", leftX + leftWidth, SELECTOR_Y + 8,
        rightX - leftX - leftWidth, "center")
end

local function algorithmButtonBounds(direction)
    local width = 30
    if direction < 0 then
        return ALGORITHM_X + 10, ALGORITHM_Y + 27, width, 24
    end
    return ALGORITHM_X + ALGORITHM_W - width - 10, ALGORITHM_Y + 27, width, 24
end

local function algorithmNameBounds()
    return ALGORITHM_X + 44, ALGORITHM_Y + 27, ALGORITHM_W - 88, 24
end

local function seedBounds()
    return ALGORITHM_X + 10, ALGORITHM_Y + 49, ALGORITHM_W - 20, 13
end

local function drawAlgorithmSelector()
    setColor(colors.panel, 0.96)
    love.graphics.rectangle("fill", ALGORITHM_X, ALGORITHM_Y, ALGORITHM_W, ALGORITHM_H, 5, 5)
    setColor(colors.border, 0.78)
    love.graphics.rectangle("line", ALGORITHM_X + 0.5, ALGORITHM_Y + 0.5, ALGORITHM_W - 1, ALGORITHM_H - 1, 5, 5)
    setColor(colors.muted)
    love.graphics.print("ALGORITHM", ALGORITHM_X + 10, ALGORITHM_Y + 8)
    local tier, tierColor = app.algorithm.tier, app.algorithm.guaranteed and colors.snake or colors.gold
    if app.algorithm.guaranteed and app.controlMode == "hybrid" then
        tier = app.hybridIntervened and "GUARANTEE LOST" or "GUARANTEE ACTIVE"
        tierColor = app.hybridIntervened and colors.food or colors.cyan
    end
    setColor(tierColor)
    love.graphics.printf(tier, ALGORITHM_X + 160, ALGORITHM_Y + 8, ALGORITHM_W - 170, "right")

    for _, direction in ipairs({ -1, 1 }) do
        local x, y, width, height = algorithmButtonBounds(direction)
        setColor(colors.background, 0.72)
        love.graphics.rectangle("fill", x, y, width, height, 3, 3)
        setColor(colors.cyan)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 3, 3)
        setColor(colors.text)
        love.graphics.printf(direction < 0 and "<" or ">", x, y + 5, width, "center")
    end
    local nameX, nameY, nameWidth = algorithmNameBounds()
    setColor(colors.text)
    love.graphics.printf(app.algorithm.label, nameX, nameY + 5, nameWidth, "center")
    setColor(colors.cyan)
    love.graphics.print("SEED " .. displaySeed(app.seedText, 28), ALGORITHM_X + 10, ALGORITHM_Y + 49)
end

local function drawHeader()
    setColor(colors.text)
    love.graphics.print("LUA LÖVE SNAKE", 42, 24)
    local targetTps = 1 / app.stepInterval
    setColor(colors.cyan)
    love.graphics.print(string.format("TPS %.0f / %.0f", app.performance.actualTps, targetTps), 42, 46)
    setColor(colors.muted)
    if app.controlMode == "manual" then
        love.graphics.print("AI -- MSPT", 42, 67)
    else
        love.graphics.print(string.format("AI %.3f MSPT", app.performance.aiMspt), 42, 67)
    end

    drawAlgorithmSelector()
    drawStatBox("SCORE", app.engine.score, SCORE_X, colors.gold, colors.gold)
    drawStatBox("BEST", activeRecord().bestScore, BEST_X, colors.snakeDark, colors.text)
    drawSelector("EDGE", edgeOptions, app.edgeMode, EDGE_X, EDGE_W, 52)
    drawSelector("CONTROL", controlOptions, app.controlMode, CONTROL_X, CONTROL_W, 70)
    drawSpeedSelector()
end

local function drawBasicOverlay()
    if app.state == "playing" or app.state == "algorithm-picker" or app.state == "leaderboard"
        or app.state == "seed-input" or app.state == "size-input" or app.state == "confirm-reset" then
        return
    end
    setColor(colors.background, 0.78)
    love.graphics.rectangle("fill", app.boardX, app.boardY, app.boardWidth, app.boardHeight)
    setColor(colors.background, 0.94)
    love.graphics.rectangle("fill", CONTENT_X, CONTENT_Y + 150, CONTENT_W, 104)
    local title, subtitle, prompt
    if app.state == "title" then
        title = "LUA LÖVE SNAKE"
        subtitle = app.controlMode == "auto" and "Press Enter to start AI" or "Press Enter or a direction key"
    elseif app.state == "paused" then
        title = "PAUSED"
        subtitle = app.pausedForFocus and "Click the game window to continue" or "Press P or Esc to continue"
    elseif app.state == "confirm-change" then
        local change = app.pendingChange
        if change.kind == "replay" then
            title = "REPLAY SEED " .. displaySeed(change.value, 20) .. "?"
        else
            local value = change.kind == "size" and BoardConfig.key(change.value.cols, change.value.rows)
                or tostring(change.value)
            title = "CHANGE " .. string.upper(change.kind) .. " TO " .. string.upper(value) .. "?"
        end
        subtitle = "This run will end and its score will not count."
        prompt = "Y  RESTART     N  CANCEL"
    elseif app.state == "won" then
        title = "BOARD FILLED"
        subtitle = "Tail reached. Enter: new seed   R: replay"
    else
        title = "GAME OVER"
        subtitle = "Enter: new seed   R: replay"
    end
    setColor(app.state == "over" and colors.food or colors.text)
    love.graphics.printf(title, CONTENT_X, CONTENT_Y + 170, CONTENT_W, "center")
    setColor(colors.muted)
    love.graphics.printf(subtitle, CONTENT_X, CONTENT_Y + 200, CONTENT_W, "center")
    if prompt then
        setColor(colors.gold)
        love.graphics.printf(prompt, CONTENT_X, CONTENT_Y + 226, CONTENT_W, "center")
    end
end

local function drawModalFrame(title, subtitle)
    setColor(colors.background, 0.93)
    love.graphics.rectangle("fill", CONTENT_X, CONTENT_Y, CONTENT_W, CONTENT_H)
    setColor(colors.panel)
    love.graphics.rectangle("fill", CONTENT_X + 36, CONTENT_Y + 28, CONTENT_W - 72, CONTENT_H - 56, 6, 6)
    setColor(colors.border)
    love.graphics.rectangle("line", CONTENT_X + 36.5, CONTENT_Y + 28.5, CONTENT_W - 73, CONTENT_H - 57, 6, 6)
    setColor(colors.text)
    love.graphics.print(title, CONTENT_X + 58, CONTENT_Y + 48)
    if subtitle then
        setColor(colors.muted)
        love.graphics.print(subtitle, CONTENT_X + 58, CONTENT_Y + 70)
    end
end

local function algorithmTileBounds(index)
    local column = (index - 1) % 2
    local row = math.floor((index - 1) / 2)
    return CONTENT_X + 58 + column * 310, CONTENT_Y + 104 + row * 82, 292, 66
end

local function drawAlgorithmPicker()
    if app.state ~= "algorithm-picker" then
        return
    end
    drawModalFrame("SELECT AI ALGORITHM", "G cycles without opening this panel")
    for index, algorithm in ipairs(Registry.list) do
        local x, y, width, height = algorithmTileBounds(index)
        local selected = algorithm.id == app.algorithmId
        setColor(selected and colors.cyan or colors.background, selected and 0.22 or 0.72)
        love.graphics.rectangle("fill", x, y, width, height, 4, 4)
        setColor(selected and colors.cyan or colors.border)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 4, 4)
        setColor(colors.text)
        love.graphics.print(algorithm.label, x + 12, y + 10)
        setColor(algorithm.guaranteed and colors.snake or colors.gold)
        love.graphics.printf(algorithm.tier, x + 170, y + 10, width - 182, "right")
        setColor(colors.muted)
        love.graphics.printf(algorithm.description, x + 12, y + 34, width - 24, "left")
    end
end


local function leaderboardTabBounds(kind, index)
    if kind == "edge" then
        return CONTENT_X + 58 + (index - 1) * 102, CONTENT_Y + 122, 96, 26
    end
    return CONTENT_X + 292 + (index - 1) * 102, CONTENT_Y + 122, 96, 26
end

local function leaderboardSizeButtonBounds(direction)
    local x = direction < 0 and CONTENT_X + 456 or CONTENT_X + 584
    return x, CONTENT_Y + 87, 34, 26
end

local function drawLeaderboardTab(label, selected, x, y, width, height)
    setColor(selected and colors.cyan or colors.background, selected and 0.24 or 0.72)
    love.graphics.rectangle("fill", x, y, width, height, 3, 3)
    setColor(selected and colors.cyan or colors.border)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 3, 3)
    setColor(selected and colors.text or colors.muted)
    love.graphics.printf(label, x, y + 6, width, "center")
end

local function formatBestRun(record)
    if not record.bestSteps then
        return "--", "--", "--"
    end
    local timing = string.format("%.2fs@%sx", record.bestTime or 0, tostring(record.bestSpeed or 1))
    return tostring(record.bestSteps), timing, displaySeed(record.bestSeed or "--", 12)
end

local function drawLeaderboard()
    if app.state ~= "leaderboard" and app.state ~= "confirm-reset" then
        return
    end
    drawModalFrame("ALGORITHM LEADERBOARD", "[ / ] changes size   L or Esc closes   Delete resets")
    local dimensions = app.leaderboardDimensions[app.leaderboardSizeIndex]
    setColor(colors.muted)
    love.graphics.print("SIZE", CONTENT_X + 350, CONTENT_Y + 94)
    for _, direction in ipairs({ -1, 1 }) do
        local x, y, width, height = leaderboardSizeButtonBounds(direction)
        drawLeaderboardTab(direction < 0 and "<" or ">", false, x, y, width, height)
    end
    setColor(colors.cyan)
    love.graphics.printf(dimensions.key, CONTENT_X + 490, CONTENT_Y + 94, 94, "center")
    for index, edge in ipairs(Constants.EDGE_MODES) do
        local x, y, width, height = leaderboardTabBounds("edge", index)
        drawLeaderboardTab(string.upper(edge), edge == app.leaderboardEdge, x, y, width, height)
    end
    for index, control in ipairs(Constants.CONTROL_MODES) do
        local x, y, width, height = leaderboardTabBounds("control", index)
        drawLeaderboardTab(string.upper(control), control == app.leaderboardControl, x, y, width, height)
    end

    local tableX, tableY = CONTENT_X + 58, CONTENT_Y + 166
    local columns = { 0, 196, 258, 334, 466, 548 }
    local labels = { "ALGORITHM", "BEST", "STEPS", "TIME@SPEED", "WINS/RUNS", "SEED" }
    setColor(colors.muted)
    for index, label in ipairs(labels) do
        love.graphics.print(label, tableX + columns[index], tableY)
    end
    setColor(colors.border)
    love.graphics.line(tableX, tableY + 20, tableX + 604, tableY + 20)

    local rows = app.leaderboardControl == "manual" and { { id = "player", label = "PLAYER" } } or Registry.list
    for index, algorithm in ipairs(rows) do
        local y = tableY + 30 + (index - 1) * 32
        local record = app.stats:get(dimensions.cols, dimensions.rows,
            app.leaderboardEdge, app.leaderboardControl, algorithm.id)
        local steps, timing, seed = formatBestRun(record)
        setColor(index % 2 == 0 and colors.background or colors.panel, 0.52)
        love.graphics.rectangle("fill", tableX - 4, y - 5, 612, 27)
        setColor(colors.text)
        love.graphics.print(algorithm.label, tableX, y)
        love.graphics.print(tostring(record.bestScore), tableX + columns[2], y)
        love.graphics.print(steps, tableX + columns[3], y)
        love.graphics.print(timing, tableX + columns[4], y)
        love.graphics.print(record.wins .. "/" .. record.runs, tableX + columns[5], y)
        love.graphics.print(seed, tableX + columns[6], y)
    end

    setColor(colors.muted)
    love.graphics.print("DATA: " .. app.statsStorage.mode, tableX, CONTENT_Y + CONTENT_H - 50)
    setColor(colors.food)
    love.graphics.printf("RESET ALL", tableX + 480, CONTENT_Y + CONTENT_H - 50, 124, "right")

    if app.state == "confirm-reset" then
        setColor(colors.background, 0.88)
        love.graphics.rectangle("fill", CONTENT_X + 150, CONTENT_Y + 190, 420, 116, 5, 5)
        setColor(colors.food)
        love.graphics.printf("RESET ALL LEADERBOARD DATA?", CONTENT_X + 150, CONTENT_Y + 220, 420, "center")
        setColor(colors.gold)
        love.graphics.printf("Y  RESET     N  CANCEL", CONTENT_X + 150, CONTENT_Y + 258, 420, "center")
    end
end

local function drawSeedInput()
    if app.state ~= "seed-input" then
        return
    end
    drawModalFrame("SET RUN SEED", "Empty input creates a random seed")
    local x, y, width, height = CONTENT_X + 120, CONTENT_Y + 190, 480, 54
    setColor(colors.background)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)
    setColor(colors.cyan)
    love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 4, 4)
    setColor(colors.text)
    love.graphics.print(app.seedBuffer .. "_", x + 14, y + 19)
    setColor(colors.muted)
    love.graphics.printf("ASCII letters, numbers, - and _   Enter: apply   Esc: cancel",
        CONTENT_X + 80, CONTENT_Y + 270, CONTENT_W - 160, "center")
end

local function sizePresetBounds(index)
    return CONTENT_X + 58 + (index - 1) * 122, CONTENT_Y + 118, 112, 42
end

local function sizeFieldBounds(field)
    return field == "width" and CONTENT_X + 100 or CONTENT_X + 400, CONTENT_Y + 218, 200, 54
end

local function sizeActionBounds(action)
    return action == "apply" and CONTENT_X + 220 or CONTENT_X + 380, CONTENT_Y + 366, 120, 38
end

local function drawSizeInput()
    if app.state ~= "size-input" then
        return
    end
    drawModalFrame("SET BOARD SIZE", "Choose a preset or enter 5-50; at least one side must be even")
    for index, preset in ipairs(BoardConfig.PRESETS) do
        local x, y, width, height = sizePresetBounds(index)
        local selected = preset.cols == app.cols and preset.rows == app.rows
        drawLeaderboardTab(BoardConfig.key(preset.cols, preset.rows), selected, x, y, width, height)
    end
    for _, field in ipairs({ "width", "height" }) do
        local x, y, width, height = sizeFieldBounds(field)
        setColor(colors.muted)
        love.graphics.print(string.upper(field), x, y - 24)
        setColor(colors.background)
        love.graphics.rectangle("fill", x, y, width, height, 4, 4)
        setColor(app.sizeField == field and colors.cyan or colors.border)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 4, 4)
        setColor(colors.text)
        local value = field == "width" and app.sizeWidthBuffer or app.sizeHeightBuffer
        love.graphics.printf(value .. (app.sizeField == field and "_" or ""), x, y + 18, width, "center")
    end
    setColor(app.sizeError and colors.food or colors.gold)
    love.graphics.printf(app.sizeError or "TAB  SWITCH FIELD     ENTER  APPLY     ESC  CANCEL",
        CONTENT_X + 58, CONTENT_Y + 314, CONTENT_W - 116, "center")
    for _, action in ipairs({ "apply", "cancel" }) do
        local x, y, width, height = sizeActionBounds(action)
        drawLeaderboardTab(string.upper(action), action == "apply", x, y, width, height)
    end
end

local function drawFooter()
    setColor(colors.muted)
    love.graphics.print("WASD / ARROWS  TURN    G  AI    L  SCORES    B  SIZE "
        .. BoardConfig.key(app.cols, app.rows), 30, BASE_H - 42)
    love.graphics.print("- / +  SPEED    R  REPLAY    P / ESC  PAUSE", 30, BASE_H - 21)
    local function down(key)
        return love.keyboard.isScancodeDown(key) and "1" or "0"
    end
    local held = string.format(
        "FOCUS:%s  W:%s A:%s S:%s D:%s  UP:%s LF:%s DN:%s RT:%s",
        app.focused and "1" or "0",
        down("w"), down("a"), down("s"), down("d"),
        down("up"), down("left"), down("down"), down("right")
    )
    setColor(colors.gold)
    love.graphics.printf(app.saveNotice or app.inputEvent, 500, BASE_H - 43, 430, "right")
    setColor(colors.muted)
    love.graphics.printf(held, 500, BASE_H - 22, 430, "right")
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.keyboard.setTextInput(false)
    love.math.setRandomSeed(os.time())
    loadSettings()
    loadStats()
    app.seedText = randomSeedText()
    resetEngine()
end

function love.update(dt)
    app.pulse = math.max(0, app.pulse - dt * 3)
    if app.state ~= "playing" then
        return
    end
    app.runElapsed = app.runElapsed + dt
    app.logicTimer = math.min(app.logicTimer + dt, app.stepInterval * Constants.MAX_STEPS_PER_FRAME)
    local frameStarted = love.timer.getTime()
    local frameDeadline = frameStarted + Constants.AI_BUDGET_SECONDS
    local steps = 0

    while app.logicTimer >= app.stepInterval and steps < Constants.MAX_STEPS_PER_FRAME do
        if app.controlMode ~= "manual" and steps > 0 and love.timer.getTime() >= frameDeadline then
            break
        end
        app.logicTimer = app.logicTimer - app.stepInterval
        local directionName, aiSeconds = chooseDirection()
        local result = app.engine:step(directionName)
        steps = steps + 1
        app.performance.ticks = app.performance.ticks + 1
        if app.controlMode ~= "manual" then
            app.performance.aiSeconds = app.performance.aiSeconds + aiSeconds
            app.performance.aiDecisions = app.performance.aiDecisions + 1
        end
        if result.ate then
            app.stepInterval = Constants.stepInterval(app.engine.score, currentSpeed())
            app.pulse = 1
        end
        if result.won or result.died then
            finishRun(result.won == true)
            break
        end
    end

    if app.logicTimer >= app.stepInterval
        and (steps == Constants.MAX_STEPS_PER_FRAME or love.timer.getTime() >= frameDeadline) then
        app.logicTimer = app.logicTimer % app.stepInterval
    end
    updatePerformance(dt)
end

function love.draw()
    local scale, offsetX, offsetY = scaleTransform()
    love.graphics.clear(0.02, 0.04, 0.05)
    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale, scale)
    drawBackground()
    drawHeader()
    drawBoard()
    drawFood()
    drawSnake()
    drawBasicOverlay()
    drawAlgorithmPicker()
    drawLeaderboard()
    drawSeedInput()
    drawSizeInput()
    drawFooter()
    love.graphics.pop()
end

local function handleSeedKey(key)
    if key == "escape" then
        closeModal()
        return
    elseif key == "return" or key == "kpenter" then
        submitSeed()
        return
    elseif key == "backspace" then
        app.seedBuffer = app.seedBuffer:sub(1, -2)
        return
    elseif key == "v" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        app.seedBuffer = sanitizeSeed(app.seedBuffer .. (love.system.getClipboardText() or ""))
        return
    end
    if #key == 1 and key:match("[%w_-]") then
        local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
        local character = key == "-" and shift and "_" or (shift and key:upper() or key)
        app.seedBuffer = sanitizeSeed(app.seedBuffer .. character)
    end
end

local function handleSizeKey(key)
    if key == "escape" then
        closeModal()
        return
    elseif key == "return" or key == "kpenter" then
        submitSize()
        return
    elseif key == "tab" or key == "left" or key == "right" then
        app.sizeField = app.sizeField == "width" and "height" or "width"
        return
    end
    local bufferName = app.sizeField == "width" and "sizeWidthBuffer" or "sizeHeightBuffer"
    if key == "backspace" then
        app[bufferName] = app[bufferName]:sub(1, -2)
        app.sizeError = nil
        return
    end
    local digit = key:match("^(%d)$") or key:match("^kp(%d)$")
    if digit and #app[bufferName] < 2 then
        app[bufferName] = app[bufferName] .. digit
        app.sizeError = nil
    end
end

local function handleLeaderboardKey(key)
    if key == "escape" or key == "l" then
        closeModal()
    elseif key == "delete" then
        requestStatsReset()
    elseif key == "left" or key == "right" then
        local delta = key == "left" and -1 or 1
        for index, control in ipairs(Constants.CONTROL_MODES) do
            if control == app.leaderboardControl then
                app.leaderboardControl = Constants.CONTROL_MODES[((index - 1 + delta) % #Constants.CONTROL_MODES) + 1]
                break
            end
        end
    elseif key == "up" or key == "down" then
        app.leaderboardEdge = app.leaderboardEdge == "walls" and "wrap" or "walls"
    elseif key == "[" then
        cycleLeaderboardSize(-1)
    elseif key == "]" then
        cycleLeaderboardSize(1)
    end
end

function love.keypressed(key, scancode)
    app.inputEvent = "DOWN  key=" .. tostring(key) .. " scan=" .. tostring(scancode)
    if app.state == "seed-input" then
        handleSeedKey(key)
        return
    elseif app.state == "size-input" then
        handleSizeKey(key)
        return
    elseif app.state == "confirm-reset" then
        if key == "y" then
            confirmStatsReset()
        elseif key == "n" or key == "escape" then
            app.state = "leaderboard"
        end
        return
    elseif app.state == "algorithm-picker" then
        if key == "escape" then
            closeModal()
        elseif tonumber(key) and tonumber(key) >= 1 and tonumber(key) <= #Registry.list then
            local returnState = app.stateBeforeModal or "title"
            app.state, app.stateBeforeModal = returnState, nil
            requestChange("algorithm", Registry.list[tonumber(key)].id)
        end
        return
    elseif app.state == "leaderboard" then
        handleLeaderboardKey(key)
        return
    elseif app.state == "confirm-change" then
        if key == "y" or scancode == "y" then
            confirmChange()
            app.inputEvent = "CHANGE  CONFIRMED"
        elseif key == "n" or scancode == "n" or key == "escape" then
            cancelChange()
            app.inputEvent = "CHANGE  CANCELLED"
        end
        return
    end

    if key == "l" or scancode == "l" then
        openLeaderboard()
        return
    elseif key == "b" or scancode == "b" then
        openSizeInput()
        return
    elseif key == "f2" then
        openSeedInput()
        return
    elseif key == "r" or scancode == "r" then
        requestReplay()
        return
    elseif key == "g" or scancode == "g" then
        cycleAlgorithm(1)
        return
    elseif key == "m" or scancode == "m" then
        cycleEdge()
        return
    elseif key == "c" or scancode == "c" then
        cycleControl()
        return
    end

    local decreaseSpeed = key == "-" or key == "_" or key == "kp-" or scancode == "-" or scancode == "kp-"
    local increaseSpeed = key == "=" or key == "+" or key == "kp+" or scancode == "=" or scancode == "kp+"
    if decreaseSpeed or increaseSpeed then
        changeSpeed(decreaseSpeed and -1 or 1)
        app.inputEvent = "SPEED  " .. tostring(currentSpeed()) .. "x"
        return
    end

    local directionName = keyDirections[scancode] or keyDirections[key]
    if directionName then
        queueDirection(directionName)
        return
    end
    if key == "return" or key == "space" then
        if app.state == "title" or app.state == "over" or app.state == "won" then
            beginRun(nil, app.state ~= "title")
        end
    elseif key == "p" or key == "escape" then
        if app.state == "playing" then
            app.state = "paused"
            app.pausedForFocus = false
        elseif app.state == "paused" then
            app.state = "playing"
            app.pausedForFocus = false
        end
    end
end

function love.keyreleased(key, scancode)
    app.inputEvent = "UP    key=" .. tostring(key) .. " scan=" .. tostring(scancode)
end

function love.focus(focused)
    app.focused = focused
    app.inputEvent = "FOCUS " .. tostring(focused)
    if not focused and app.state == "playing" then
        app.state = "paused"
        app.pausedForFocus = true
    elseif not focused and app.stateBeforeModal == "playing" then
        app.stateBeforeModal = "paused"
        app.pausedForFocus = true
    elseif focused and app.state == "paused" and app.pausedForFocus then
        app.state = "playing"
        app.pausedForFocus = false
    end
end

local function handleModalClick(x, y)
    if app.state == "algorithm-picker" then
        for index, algorithm in ipairs(Registry.list) do
            local tileX, tileY, width, height = algorithmTileBounds(index)
            if pointInRect(x, y, tileX, tileY, width, height) then
                local returnState = app.stateBeforeModal or "title"
                app.state, app.stateBeforeModal = returnState, nil
                requestChange("algorithm", algorithm.id)
                return true
            end
        end
        return true
    elseif app.state == "leaderboard" then
        for _, direction in ipairs({ -1, 1 }) do
            local buttonX, buttonY, width, height = leaderboardSizeButtonBounds(direction)
            if pointInRect(x, y, buttonX, buttonY, width, height) then
                cycleLeaderboardSize(direction)
                return true
            end
        end
        for index, edge in ipairs(Constants.EDGE_MODES) do
            local tabX, tabY, width, height = leaderboardTabBounds("edge", index)
            if pointInRect(x, y, tabX, tabY, width, height) then
                app.leaderboardEdge = edge
                return true
            end
        end
        for index, control in ipairs(Constants.CONTROL_MODES) do
            local tabX, tabY, width, height = leaderboardTabBounds("control", index)
            if pointInRect(x, y, tabX, tabY, width, height) then
                app.leaderboardControl = control
                return true
            end
        end
        if pointInRect(x, y, CONTENT_X + 530, CONTENT_Y + CONTENT_H - 66, 132, 34) then
            requestStatsReset()
        end
        return true
    elseif app.state == "size-input" then
        for index, preset in ipairs(BoardConfig.PRESETS) do
            local presetX, presetY, width, height = sizePresetBounds(index)
            if pointInRect(x, y, presetX, presetY, width, height) then
                submitSize(preset.cols, preset.rows)
                return true
            end
        end
        for _, field in ipairs({ "width", "height" }) do
            local fieldX, fieldY, width, height = sizeFieldBounds(field)
            if pointInRect(x, y, fieldX, fieldY, width, height) then
                app.sizeField = field
                return true
            end
        end
        for _, action in ipairs({ "apply", "cancel" }) do
            local actionX, actionY, width, height = sizeActionBounds(action)
            if pointInRect(x, y, actionX, actionY, width, height) then
                if action == "apply" then submitSize() else closeModal() end
                return true
            end
        end
        return true
    elseif app.state == "seed-input" or app.state == "confirm-reset" then
        return true
    end
    return false
end

function love.mousepressed(x, y, button)
    app.inputEvent = "MOUSE button=" .. tostring(button)
    if button ~= 1 then
        return
    end
    local scale, offsetX, offsetY = scaleTransform()
    local logicalX, logicalY = (x - offsetX) / scale, (y - offsetY) / scale
    if handleModalClick(logicalX, logicalY) then
        return
    end
    if app.state == "confirm-change" then
        return
    end

    for _, direction in ipairs({ -1, 1 }) do
        local buttonX, buttonY, width, height = algorithmButtonBounds(direction)
        if pointInRect(logicalX, logicalY, buttonX, buttonY, width, height) then
            cycleAlgorithm(direction)
            return
        end
    end
    local nameX, nameY, nameWidth, nameHeight = algorithmNameBounds()
    if pointInRect(logicalX, logicalY, nameX, nameY, nameWidth, nameHeight) then
        openModal("algorithm-picker")
        return
    end
    local seedX, seedY, seedWidth, seedHeight = seedBounds()
    if pointInRect(logicalX, logicalY, seedX, seedY, seedWidth, seedHeight) then
        openSeedInput()
        return
    end
    if pointInRect(logicalX, logicalY, BEST_X, 20, 110, 64) then
        openLeaderboard()
        return
    end

    local edge = optionAtPoint(edgeOptions, logicalX, logicalY, EDGE_X, EDGE_W, 52)
    if edge then
        requestChange("edge", edge)
        return
    end
    local control = optionAtPoint(controlOptions, logicalX, logicalY, CONTROL_X, CONTROL_W, 70)
    if control then
        requestChange("control", control)
        return
    end
    for _, direction in ipairs({ -1, 1 }) do
        local buttonX, buttonY, width, height = speedButtonBounds(direction)
        if pointInRect(logicalX, logicalY, buttonX, buttonY, width, height) then
            changeSpeed(direction)
            return
        end
    end

    local inHeaderControl = pointInRect(logicalX, logicalY, ALGORITHM_X, ALGORITHM_Y, ALGORITHM_W, ALGORITHM_H)
        or pointInRect(logicalX, logicalY, EDGE_X, SELECTOR_Y, EDGE_W, SELECTOR_H)
        or pointInRect(logicalX, logicalY, CONTROL_X, SELECTOR_Y, CONTROL_W, SELECTOR_H)
        or pointInRect(logicalX, logicalY, SPEED_X, SELECTOR_Y, SPEED_W, SELECTOR_H)
    if inHeaderControl then
        return
    end
    if app.state == "title" or app.state == "over" or app.state == "won" then
        beginRun(nil, app.state ~= "title")
    end
end

return app
