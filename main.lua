local BASE_W, BASE_H = 960, 720
local CELL = 24
local COLS, ROWS = 30, 21
local BOARD_X = (BASE_W - COLS * CELL) / 2
local BOARD_Y = 132
local EDGE_X, CONTROL_X, SPEED_X = 42, 278, 682
local SELECTOR_Y, SELECTOR_H = 94, 30
local EDGE_W, CONTROL_W, SPEED_W = 220, 390, 236
local MAX_STEPS_PER_FRAME = 2048

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

local directions = {
    up = { x = 0, y = -1, opposite = "down" },
    down = { x = 0, y = 1, opposite = "up" },
    left = { x = -1, y = 0, opposite = "right" },
    right = { x = 1, y = 0, opposite = "left" },
}

local moveDirections = {
    U = "up",
    D = "down",
    L = "left",
    R = "right",
}

local keyDirections = {
    w = "up", up = "up",
    s = "down", down = "down",
    a = "left", left = "left",
    d = "right", right = "right",
}

local edgeModes = {
    { id = "walls", label = "WALLS", color = colors.gold },
    { id = "wrap", label = "WRAP", color = colors.snake },
}

local controlModes = {
    { id = "manual", label = "MANUAL", color = colors.gold },
    { id = "auto", label = "AUTO", color = colors.snake },
    { id = "hybrid", label = "HYBRID", color = colors.cyan },
}

local speedPresets = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 25, 50, 100, 1000, 10000 }
local DEFAULT_SPEED_INDEX = 2
local game = {}

local function cellKey(x, y)
    return (y - 1) * COLS + x
end

local function setColor(color, alpha)
    love.graphics.setColor(color[1] / 255, color[2] / 255, color[3] / 255, alpha or 1)
end

local function cellToPixel(cell)
    return BOARD_X + (cell.x - 1) * CELL, BOARD_Y + (cell.y - 1) * CELL
end

local function buildCycle()
    local route = require("ai-cycle")
    assert(route.cols == COLS and route.rows == ROWS, "AI route dimensions do not match the board")
    assert(#route.moves == COLS * ROWS, "AI route must contain one move per cell")

    local cells = { { x = 1, y = 1 } }
    local index = { [cellKey(1, 1)] = 1 }
    local cycleDirections = {}
    local x, y = 1, 1

    for moveIndex = 1, #route.moves do
        local directionName = moveDirections[route.moves:sub(moveIndex, moveIndex)]
        assert(directionName, "AI route contains an unknown move")
        cycleDirections[moveIndex] = directionName
        local heading = directions[directionName]
        x = x + heading.x
        y = y + heading.y

        if moveIndex < #route.moves then
            assert(x >= 1 and x <= COLS and y >= 1 and y <= ROWS, "AI route leaves the board")
            local key = cellKey(x, y)
            assert(not index[key], "AI route visits a cell more than once")
            cells[#cells + 1] = { x = x, y = y }
            index[key] = #cells
        end
    end

    assert(x == 1 and y == 1, "AI route is not a closed cycle")
    assert(#cells == COLS * ROWS, "AI route does not cover the board")
    return { cells = cells, index = index, directions = cycleDirections }
end

local cycle = buildCycle()

local function newSnake(cells)
    local snake = { first = 0, last = #cells - 1, segments = {}, occupied = {} }
    for listIndex, cell in ipairs(cells) do
        local index = listIndex - 1
        local segment = { x = cell.x, y = cell.y }
        snake.segments[index] = segment
        snake.occupied[cellKey(segment.x, segment.y)] = true
    end
    return snake
end

local function snakeLength()
    return game.snake.last - game.snake.first + 1
end

local function snakeHead()
    return game.snake.segments[game.snake.first]
end

local function snakeTail()
    return game.snake.segments[game.snake.last]
end

local function pushSnakeHead(cell)
    game.snake.first = game.snake.first - 1
    game.snake.segments[game.snake.first] = cell
    game.snake.occupied[cellKey(cell.x, cell.y)] = true
end

local function popSnakeTail()
    local tail = snakeTail()
    game.snake.occupied[cellKey(tail.x, tail.y)] = nil
    game.snake.segments[game.snake.last] = nil
    game.snake.last = game.snake.last - 1
    return tail
end

local function containsSnake(x, y)
    return game.snake.occupied[cellKey(x, y)] == true
end

local function ensureBestScores(existing)
    local scores = type(existing) == "table" and existing or {}
    for _, edge in ipairs(edgeModes) do
        if type(scores[edge.id]) ~= "table" then
            scores[edge.id] = {}
        end
        for _, control in ipairs(controlModes) do
            scores[edge.id][control.id] = scores[edge.id][control.id] or 0
        end
    end
    return scores
end

local function activeBestScore()
    return game.bestScores[game.edgeMode][game.controlMode]
end

local function recordBestScore()
    local current = activeBestScore()
    game.bestScores[game.edgeMode][game.controlMode] = math.max(current, game.score)
end

local function currentSpeed()
    return speedPresets[game.speedIndex or DEFAULT_SPEED_INDEX]
end

local function calculateStepInterval(score, speed)
    local currentCurve = math.max(0.06, 0.145 - score * 0.0035)
    return currentCurve * 2 / speed
end

local function spawnFood()
    local open = {}
    for y = 1, ROWS do
        for x = 1, COLS do
            if not containsSnake(x, y) then
                open[#open + 1] = { x = x, y = y }
            end
        end
    end

    if #open == 0 then
        game.food = nil
        game.tailFinishReady = true
        return
    end
    game.food = open[love.math.random(1, #open)]
end

local function buildManualSnake(directionName)
    local heading = directions[directionName]
    local cells = {}
    for offset = 0, 3 do
        cells[#cells + 1] = {
            x = 15 - heading.x * offset,
            y = 11 - heading.y * offset,
        }
    end
    return newSnake(cells), directionName
end

local function buildAiSnake()
    local headIndex = cycle.index[cellKey(15, 11)]
    local cells = {}
    for offset = 0, 3 do
        local index = ((headIndex - 1 - offset) % #cycle.cells) + 1
        local cell = cycle.cells[index]
        cells[#cells + 1] = { x = cell.x, y = cell.y }
    end
    return newSnake(cells), cycle.directions[headIndex]
end

local function resetGame(initialDirection)
    local previous = game
    local edgeMode = previous.edgeMode or "walls"
    local controlMode = previous.controlMode or "manual"
    local speedIndex = previous.speedIndex or DEFAULT_SPEED_INDEX
    local snake, startDirection

    if controlMode == "manual" then
        snake, startDirection = buildManualSnake(initialDirection or "right")
    else
        snake, startDirection = buildAiSnake()
    end

    game = {
        state = "title",
        snake = snake,
        direction = startDirection,
        queuedDirection = startDirection,
        turnQueued = false,
        hybridOverride = nil,
        hybridIntervened = false,
        food = { x = 21, y = 11 },
        tailFinishReady = false,
        score = 0,
        edgeMode = edgeMode,
        controlMode = controlMode,
        speedIndex = speedIndex,
        bestScores = ensureBestScores(previous.bestScores),
        timer = 0,
        stepInterval = calculateStepInterval(0, speedPresets[speedIndex]),
        pulse = 0,
        focused = previous.focused ~= false,
        pausedForFocus = false,
        inputEvent = previous.inputEvent or "WAITING FOR INPUT",
    }

    if containsSnake(game.food.x, game.food.y) then
        spawnFood()
    end
end

local function canChangeSetting()
    return game.state == "title" or game.state == "over" or game.state == "won"
        or game.state == "playing" or game.state == "paused"
end

local function isBetweenRounds()
    return game.state == "title" or game.state == "over" or game.state == "won"
end

local function requestSetting(kind, value)
    if not canChangeSetting() then
        return false
    end

    local current = kind == "edge" and game.edgeMode or game.controlMode
    if current == value then
        return true
    end

    if isBetweenRounds() then
        if kind == "edge" then
            game.edgeMode = value
        else
            game.controlMode = value
        end
        resetGame()
    else
        game.pendingChange = { kind = kind, value = value }
        game.stateBeforePrompt = game.state
        game.state = "confirm-change"
    end
    return true
end

local function requestEdgeMode(mode)
    if mode ~= "walls" and mode ~= "wrap" then
        return false
    end
    return requestSetting("edge", mode)
end

local function requestControlMode(mode)
    if mode ~= "manual" and mode ~= "auto" and mode ~= "hybrid" then
        return false
    end
    return requestSetting("control", mode)
end

local function toggleEdgeMode()
    requestEdgeMode(game.edgeMode == "walls" and "wrap" or "walls")
end

local function cycleControlMode()
    for index, option in ipairs(controlModes) do
        if option.id == game.controlMode then
            local nextOption = controlModes[index % #controlModes + 1]
            requestControlMode(nextOption.id)
            return
        end
    end
end

local function confirmSettingChange()
    if game.state ~= "confirm-change" or not game.pendingChange then
        return
    end
    if game.pendingChange.kind == "edge" then
        game.edgeMode = game.pendingChange.value
    else
        game.controlMode = game.pendingChange.value
    end
    resetGame()
    game.state = "playing"
end

local function cancelSettingChange()
    if game.state ~= "confirm-change" then
        return
    end
    game.state = game.stateBeforePrompt or "playing"
    game.pendingChange = nil
    game.stateBeforePrompt = nil
end

local function setSpeedIndex(index)
    local nextIndex = math.max(1, math.min(#speedPresets, index))
    if nextIndex == game.speedIndex then
        return false
    end

    local previousInterval = game.stepInterval
    local progress = previousInterval > 0 and math.min(game.timer / previousInterval, 1) or 0
    game.speedIndex = nextIndex
    game.stepInterval = calculateStepInterval(game.score, currentSpeed())
    game.timer = progress * game.stepInterval
    return true
end

local function changeSpeed(delta)
    if game.state == "confirm-change" then
        return false
    end
    return setSpeedIndex(game.speedIndex + delta)
end

local function startGame(initialDirection)
    resetGame(initialDirection)
    game.state = "playing"
end

local function normalizedNext(directionName)
    local heading = directions[directionName]
    local head = snakeHead()
    local x, y = head.x + heading.x, head.y + heading.y
    local outside = x < 1 or x > COLS or y < 1 or y > ROWS
    if outside and game.edgeMode == "wrap" then
        x = (x - 1) % COLS + 1
        y = (y - 1) % ROWS + 1
    end
    return x, y, outside
end

local function isMoveSafe(directionName)
    if directionName == directions[game.direction].opposite then
        return false
    end

    local x, y, outside = normalizedNext(directionName)
    if outside and game.edgeMode == "walls" then
        return false
    end

    local eating = game.food and x == game.food.x and y == game.food.y
    if not containsSnake(x, y) then
        return true
    end
    local tail = snakeTail()
    return not eating and x == tail.x and y == tail.y
end

local clockwise = { up = "right", right = "down", down = "left", left = "up" }
local counterClockwise = { up = "left", left = "down", down = "right", right = "up" }

local function selectAiDirection()
    local head = snakeHead()
    local cycleIndex = cycle.index[cellKey(head.x, head.y)]
    local routeDirection = cycleIndex and cycle.directions[cycleIndex] or nil
    local candidates = {
        routeDirection,
        game.direction,
        clockwise[game.direction],
        counterClockwise[game.direction],
    }
    local seen = {}

    for _, directionName in ipairs(candidates) do
        if directionName and not seen[directionName] then
            seen[directionName] = true
            if isMoveSafe(directionName) then
                return directionName
            end
        end
    end
    return game.direction
end

local function queueDirection(directionName)
    if game.controlMode == "auto" then
        game.inputEvent = "AUTO  DIRECTION IGNORED"
        return
    end

    if game.state == "title" or game.state == "over" or game.state == "won" then
        if game.controlMode == "manual" then
            startGame(directionName)
        else
            startGame()
            if directionName ~= directions[game.direction].opposite then
                game.hybridOverride = directionName
            end
        end
        return
    end

    if game.state ~= "playing" or directionName == directions[game.direction].opposite then
        return
    end

    if game.controlMode == "manual" then
        if not game.turnQueued then
            game.queuedDirection = directionName
            game.turnQueued = true
        end
    else
        game.hybridOverride = directionName
    end
end

local function endGame()
    game.state = "over"
    recordBestScore()
end

local function step()
    local nextDirection
    if game.controlMode == "manual" then
        nextDirection = game.queuedDirection
        game.turnQueued = false
    else
        local aiDirection = selectAiDirection()
        nextDirection = aiDirection
        if game.controlMode == "hybrid" and game.hybridOverride then
            nextDirection = game.hybridOverride
            if nextDirection ~= aiDirection then
                game.hybridIntervened = true
            end
            game.hybridOverride = nil
        end
    end

    game.direction = nextDirection
    game.queuedDirection = nextDirection
    local nextX, nextY, outside = normalizedNext(nextDirection)
    if outside and game.edgeMode == "walls" then
        endGame()
        return
    end

    local eating = game.food and nextX == game.food.x and nextY == game.food.y
    local tail = snakeTail()
    local enteringTail = nextX == tail.x and nextY == tail.y
    if containsSnake(nextX, nextY) and not (not eating and enteringTail) then
        endGame()
        return
    end

    if not eating then
        popSnakeTail()
    end
    pushSnakeHead({ x = nextX, y = nextY })

    if game.tailFinishReady and enteringTail and snakeLength() == COLS * ROWS then
        game.state = "won"
        recordBestScore()
        return
    end

    if eating then
        game.score = game.score + 1
        game.stepInterval = calculateStepInterval(game.score, currentSpeed())
        game.pulse = 1
        spawnFood()
    end
end

local function scaleTransform()
    local width, height = love.graphics.getDimensions()
    local scale = math.min(width / BASE_W, height / BASE_H)
    return scale, (width - BASE_W * scale) / 2, (height - BASE_H * scale) / 2
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
    love.graphics.rectangle("fill", BOARD_X - 8, BOARD_Y - 8, COLS * CELL + 16, ROWS * CELL + 16, 6, 6)
    setColor(colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", BOARD_X - 1, BOARD_Y - 1, COLS * CELL + 2, ROWS * CELL + 2)
    love.graphics.setLineWidth(1)

    setColor(colors.grid, 0.42)
    for x = 0, COLS do
        love.graphics.line(BOARD_X + x * CELL, BOARD_Y, BOARD_X + x * CELL, BOARD_Y + ROWS * CELL)
    end
    for y = 0, ROWS do
        love.graphics.line(BOARD_X, BOARD_Y + y * CELL, BOARD_X + COLS * CELL, BOARD_Y + y * CELL)
    end
end

local function drawFood()
    if not game.food then
        return
    end
    local x, y = cellToPixel(game.food)
    local wobble = math.sin(love.timer.getTime() * 5) * 1.2
    setColor(colors.food)
    love.graphics.circle("fill", x + CELL / 2, y + CELL / 2 + wobble, 8)
    setColor(colors.gold)
    love.graphics.rectangle("fill", x + 11, y + 2 + wobble, 3, 5)
    setColor(colors.text, 0.55)
    love.graphics.circle("fill", x + 9, y + 9 + wobble, 2)
end

local function drawSnake()
    for index = game.snake.last, game.snake.first, -1 do
        local segment = game.snake.segments[index]
        local x, y = cellToPixel(segment)
        local isHead = index == game.snake.first
        local inset = isHead and 2 or 3
        setColor(isHead and colors.snake or colors.snakeDark)
        love.graphics.rectangle("fill", x + inset, y + inset, CELL - inset * 2, CELL - inset * 2, 5, 5)
    end

    local head = snakeHead()
    local x, y = cellToPixel(head)
    local direction = directions[game.direction]
    local eyeOffsetX = direction.x ~= 0 and direction.x * 4 or 0
    local eyeOffsetY = direction.y ~= 0 and direction.y * 4 or 0
    setColor(colors.background)
    love.graphics.circle("fill", x + 8 + eyeOffsetX, y + 8 + eyeOffsetY, 2)
    love.graphics.circle("fill", x + 16 + eyeOffsetX, y + 16 + eyeOffsetY, 2)
end

local function drawStatBox(label, value, x, accent, valueColor)
    local y, width, height = 20, 110, 64
    setColor(colors.panel, 0.96)
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)
    setColor(colors.border, 0.78)
    love.graphics.setLineWidth(1)
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
        if x >= segmentX and x <= segmentX + width and y >= segmentY and y <= segmentY + height then
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
        local enabled = direction < 0 and game.speedIndex > 1 or direction > 0 and game.speedIndex < #speedPresets
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

local function drawHeader()
    setColor(colors.text)
    love.graphics.print("LUA LÖVE SNAKE", 42, 28)

    local status, statusColor = "MANUAL CONTROL", colors.muted
    if game.controlMode == "auto" then
        status, statusColor = "AI GUARANTEE: ACTIVE", colors.snake
    elseif game.controlMode == "hybrid" and game.hybridIntervened then
        status, statusColor = "AI GUARANTEE: LOST", colors.food
    elseif game.controlMode == "hybrid" then
        status, statusColor = "AI GUARANTEE: ACTIVE", colors.cyan
    end
    setColor(statusColor)
    love.graphics.print(status, 42, 56)

    drawStatBox("SCORE", game.score, 682, colors.gold, colors.gold)
    drawStatBox("BEST", activeBestScore(), 808, colors.snakeDark, colors.text)
    drawSelector("EDGE", edgeModes, game.edgeMode, EDGE_X, EDGE_W, 52)
    drawSelector("CONTROL", controlModes, game.controlMode, CONTROL_X, CONTROL_W, 70)
    drawSpeedSelector()
end

local function drawStateOverlay()
    if game.state == "playing" then
        return
    end
    setColor(colors.background, 0.78)
    love.graphics.rectangle("fill", BOARD_X, BOARD_Y, COLS * CELL, ROWS * CELL)

    local title, subtitle, prompt
    if game.state == "title" then
        title = "LUA LÖVE SNAKE"
        if game.controlMode == "auto" then
            subtitle = "Press Enter to start AI"
        else
            subtitle = "Press Enter or a direction key"
        end
    elseif game.state == "paused" then
        title = "PAUSED"
        subtitle = game.pausedForFocus and "Click the game window to continue" or "Press P or Esc to continue"
    elseif game.state == "confirm-change" then
        local change = game.pendingChange
        title = "CHANGE " .. string.upper(change.kind) .. " TO " .. string.upper(change.value) .. "?"
        subtitle = "This run will end and its score will not count."
        prompt = "Y  RESTART     N  CANCEL"
    elseif game.state == "won" then
        title = "BOARD FILLED"
        subtitle = "Tail reached. Press Enter to play again"
    else
        title = "GAME OVER"
        subtitle = "Press Enter to try again"
    end

    setColor(game.state == "over" and colors.food or colors.text)
    love.graphics.printf(title, BOARD_X, BOARD_Y + 210, COLS * CELL, "center")
    setColor(colors.muted)
    love.graphics.printf(subtitle, BOARD_X, BOARD_Y + 240, COLS * CELL, "center")
    if prompt then
        setColor(colors.gold)
        love.graphics.printf(prompt, BOARD_X, BOARD_Y + 266, COLS * CELL, "center")
    end
end

local function drawFooter()
    setColor(colors.muted)
    love.graphics.print("WASD / ARROWS  TURN    C  CONTROL    M  EDGE", 30, BASE_H - 42)
    love.graphics.print("- / +  SPEED    P / ESC  PAUSE", 30, BASE_H - 21)

    local function down(key)
        return love.keyboard.isScancodeDown(key) and "1" or "0"
    end
    local held = string.format(
        "FOCUS:%s  W:%s A:%s S:%s D:%s  UP:%s LF:%s DN:%s RT:%s",
        game.focused and "1" or "0",
        down("w"), down("a"), down("s"), down("d"),
        down("up"), down("left"), down("down"), down("right")
    )
    setColor(colors.gold)
    love.graphics.printf(game.inputEvent, 460, BASE_H - 43, 470, "right")
    setColor(colors.muted)
    love.graphics.printf(held, 460, BASE_H - 22, 470, "right")
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.keyboard.setTextInput(false)
    love.math.setRandomSeed(os.time())
    resetGame()
end

function love.update(dt)
    game.pulse = math.max(0, game.pulse - dt * 3)
    if game.state ~= "playing" then
        return
    end

    game.timer = math.min(game.timer + dt, game.stepInterval * MAX_STEPS_PER_FRAME)
    local steps = 0
    while game.timer >= game.stepInterval and steps < MAX_STEPS_PER_FRAME do
        game.timer = game.timer - game.stepInterval
        step()
        steps = steps + 1
        if game.state ~= "playing" then
            break
        end
    end
    if steps == MAX_STEPS_PER_FRAME and game.timer >= game.stepInterval then
        game.timer = game.timer % game.stepInterval
    end
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
    drawStateOverlay()
    drawFooter()
    love.graphics.pop()
end

function love.keypressed(key, scancode)
    game.inputEvent = "DOWN  key=" .. tostring(key) .. " scan=" .. tostring(scancode)
    if game.state == "confirm-change" then
        if key == "y" or scancode == "y" then
            confirmSettingChange()
            game.inputEvent = "CHANGE  CONFIRMED"
        elseif key == "n" or scancode == "n" then
            cancelSettingChange()
            game.inputEvent = "CHANGE  CANCELLED"
        end
        return
    end

    if (key == "m" or scancode == "m") and canChangeSetting() then
        toggleEdgeMode()
        game.inputEvent = game.state == "confirm-change" and "EDGE  CONFIRM" or "EDGE  " .. string.upper(game.edgeMode)
        return
    end
    if (key == "c" or scancode == "c") and canChangeSetting() then
        cycleControlMode()
        game.inputEvent = game.state == "confirm-change" and "CONTROL  CONFIRM"
            or "CONTROL  " .. string.upper(game.controlMode)
        return
    end

    local decreaseSpeed = key == "-" or key == "_" or key == "kp-" or scancode == "-" or scancode == "kp-"
    local increaseSpeed = key == "=" or key == "+" or key == "kp+" or scancode == "=" or scancode == "kp+"
    if decreaseSpeed or increaseSpeed then
        changeSpeed(decreaseSpeed and -1 or 1)
        game.inputEvent = "SPEED  " .. tostring(currentSpeed()) .. "x"
        return
    end

    local directionName = keyDirections[scancode] or keyDirections[key]
    if directionName then
        queueDirection(directionName)
        return
    end

    if key == "return" or key == "space" then
        if game.state == "title" or game.state == "over" or game.state == "won" then
            startGame()
        end
    elseif key == "p" or key == "escape" then
        if game.state == "playing" then
            game.state = "paused"
            game.pausedForFocus = false
        elseif game.state == "paused" then
            game.state = "playing"
            game.pausedForFocus = false
        end
    end
end

function love.keyreleased(key, scancode)
    game.inputEvent = "UP    key=" .. tostring(key) .. " scan=" .. tostring(scancode)
end

function love.focus(focused)
    game.focused = focused
    game.inputEvent = "FOCUS " .. tostring(focused)
    if not focused and game.state == "playing" then
        game.state = "paused"
        game.pausedForFocus = true
    elseif focused and game.state == "paused" and game.pausedForFocus then
        game.state = "playing"
        game.pausedForFocus = false
    end
end

local function pointInRect(x, y, rectX, rectY, width, height)
    return x >= rectX and x <= rectX + width and y >= rectY and y <= rectY + height
end

function love.mousepressed(x, y, button)
    game.inputEvent = "MOUSE button=" .. tostring(button)
    if button ~= 1 then
        return
    end

    local scale, offsetX, offsetY = scaleTransform()
    local logicalX, logicalY = (x - offsetX) / scale, (y - offsetY) / scale
    if canChangeSetting() then
        local edge = optionAtPoint(edgeModes, logicalX, logicalY, EDGE_X, EDGE_W, 52)
        if edge and requestEdgeMode(edge) then
            game.inputEvent = game.state == "confirm-change" and "EDGE  CONFIRM" or "EDGE  " .. string.upper(game.edgeMode)
            return
        end
        local control = optionAtPoint(controlModes, logicalX, logicalY, CONTROL_X, CONTROL_W, 70)
        if control and requestControlMode(control) then
            game.inputEvent = game.state == "confirm-change" and "CONTROL  CONFIRM"
                or "CONTROL  " .. string.upper(game.controlMode)
            return
        end
    end

    if game.state ~= "confirm-change" then
        for _, direction in ipairs({ -1, 1 }) do
            local buttonX, buttonY, width, height = speedButtonBounds(direction)
            if pointInRect(logicalX, logicalY, buttonX, buttonY, width, height) then
                changeSpeed(direction)
                game.inputEvent = "SPEED  " .. tostring(currentSpeed()) .. "x"
                return
            end
        end
    end

    local inSelectorRow = pointInRect(logicalX, logicalY, EDGE_X, SELECTOR_Y, EDGE_W, SELECTOR_H)
        or pointInRect(logicalX, logicalY, CONTROL_X, SELECTOR_Y, CONTROL_W, SELECTOR_H)
        or pointInRect(logicalX, logicalY, SPEED_X, SELECTOR_Y, SPEED_W, SELECTOR_H)
    if inSelectorRow then
        return
    end

    if game.state == "title" or game.state == "over" or game.state == "won" then
        startGame()
    end
end
