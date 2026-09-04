local BASE_W, BASE_H = 960, 720
local CELL = 24
local COLS, ROWS = 30, 21
local BOARD_X = (BASE_W - COLS * CELL) / 2
local BOARD_Y = 132
local MODE_X, MODE_Y = 326, 20
local MODE_W, MODE_H = 242, 64

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
}

local game = {}

local directions = {
    up = { x = 0, y = -1, opposite = "down" },
    down = { x = 0, y = 1, opposite = "up" },
    left = { x = -1, y = 0, opposite = "right" },
    right = { x = 1, y = 0, opposite = "left" },
}

local keyDirections = {
    w = "up", up = "up",
    s = "down", down = "down",
    a = "left", left = "left",
    d = "right", right = "right",
}

local modes = {
    { id = "walls", label = "WALLS", color = colors.gold },
    { id = "wrap", label = "WRAP", color = colors.snake },
}

local function setColor(color, alpha)
    love.graphics.setColor(color[1] / 255, color[2] / 255, color[3] / 255, alpha or 1)
end

local function cellToPixel(cell)
    return BOARD_X + (cell.x - 1) * CELL, BOARD_Y + (cell.y - 1) * CELL
end

local function containsSnake(x, y, ignoreTail)
    local limit = #game.snake - (ignoreTail and 1 or 0)
    for i = 1, limit do
        local segment = game.snake[i]
        if segment.x == x and segment.y == y then
            return true
        end
    end
    return false
end

local function canChangeMode()
    return game.state == "title" or game.state == "over" or game.state == "won"
        or game.state == "playing" or game.state == "paused"
end

local function isBetweenRounds()
    return game.state == "title" or game.state == "over" or game.state == "won"
end

local function activeBestScore()
    return game.bestScores and game.bestScores[game.mode] or 0
end

local function recordBestScore()
    game.bestScores[game.mode] = math.max(activeBestScore(), game.score)
end

local function spawnFood()
    local open = {}
    for y = 1, ROWS do
        for x = 1, COLS do
            if not containsSnake(x, y) then
                table.insert(open, { x = x, y = y })
            end
        end
    end
    if #open == 0 then
        recordBestScore()
        game.state = "won"
        return
    end
    game.food = open[love.math.random(1, #open)]
end

local function resetGame(initialDirection)
    local startDirection = initialDirection or "right"
    local heading = directions[startDirection]
    local selectedMode = game.mode or "walls"
    local bestScores = game.bestScores or {
        walls = game.bestScore or 0,
        wrap = 0,
    }
    local snake = {}
    for i = 0, 3 do
        snake[#snake + 1] = {
            x = 15 - heading.x * i,
            y = 11 - heading.y * i,
        }
    end

    game = {
        state = "title",
        snake = snake,
        direction = startDirection,
        queuedDirection = startDirection,
        food = { x = 21, y = 11 },
        score = 0,
        mode = selectedMode,
        bestScores = bestScores,
        timer = 0,
        stepInterval = 0.145,
        pulse = 0,
        focused = game.focused ~= false,
        pausedForFocus = false,
        inputEvent = game.inputEvent or "WAITING FOR INPUT",
    }
end

local function requestMode(mode)
    if not canChangeMode() or (mode ~= "walls" and mode ~= "wrap") then
        return false
    end
    if game.mode == mode then
        return true
    end
    if isBetweenRounds() then
        game.mode = mode
        resetGame()
    else
        game.pendingMode = mode
        game.stateBeforeModePrompt = game.state
        game.state = "confirm-mode"
    end
    return true
end

local function toggleMode()
    requestMode(game.mode == "walls" and "wrap" or "walls")
end

local function confirmModeChange()
    if game.state ~= "confirm-mode" or not game.pendingMode then
        return
    end
    game.mode = game.pendingMode
    resetGame()
    game.state = "playing"
end

local function cancelModeChange()
    if game.state ~= "confirm-mode" then
        return
    end
    game.state = game.stateBeforeModePrompt or "playing"
    game.pendingMode = nil
    game.stateBeforeModePrompt = nil
end

local function startGame(initialDirection)
    resetGame(initialDirection)
    game.state = "playing"
end

local function queueDirection(direction)
    if game.state == "title" or game.state == "over" or game.state == "won" then
        startGame(direction)
        return
    end
    if game.state ~= "playing" then
        return
    end
    if direction ~= directions[game.direction].opposite then
        game.queuedDirection = direction
    end
end

local function endGame()
    game.state = "over"
    recordBestScore()
end

local function step()
    game.direction = game.queuedDirection
    local heading = directions[game.direction]
    local head = game.snake[1]
    local nextHead = { x = head.x + heading.x, y = head.y + heading.y }
    local outside = nextHead.x < 1 or nextHead.x > COLS or nextHead.y < 1 or nextHead.y > ROWS

    if outside and game.mode == "walls" then
        endGame()
        return
    end
    if outside then
        nextHead.x = (nextHead.x - 1) % COLS + 1
        nextHead.y = (nextHead.y - 1) % ROWS + 1
    end

    local eating = nextHead.x == game.food.x and nextHead.y == game.food.y
    if containsSnake(nextHead.x, nextHead.y, not eating) then
        endGame()
        return
    end

    table.insert(game.snake, 1, nextHead)
    if eating then
        game.score = game.score + 1
        game.stepInterval = math.max(0.06, 0.145 - game.score * 0.0035)
        game.pulse = 1
        spawnFood()
    else
        table.remove(game.snake)
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
    love.graphics.rectangle("fill", 0, 0, BASE_W, 96)
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
    for i = #game.snake, 1, -1 do
        local segment = game.snake[i]
        local x, y = cellToPixel(segment)
        local inset = i == 1 and 2 or 3
        setColor(i == 1 and colors.snake or colors.snakeDark)
        love.graphics.rectangle("fill", x + inset, y + inset, CELL - inset * 2, CELL - inset * 2, 5, 5)
    end

    local head = game.snake[1]
    local x, y = cellToPixel(head)
    local direction = directions[game.direction]
    local eyeOffsetX, eyeOffsetY = 0, 0
    if direction.x ~= 0 then
        eyeOffsetX = direction.x * 4
    else
        eyeOffsetY = direction.y * 4
    end
    setColor(colors.background)
    love.graphics.circle("fill", x + 8 + eyeOffsetX, y + 8 + eyeOffsetY, 2)
    love.graphics.circle("fill", x + 16 + eyeOffsetX, y + 16 + eyeOffsetY, 2)
end

local function drawStatBox(label, value, x, accent, valueColor)
    local y, width, height = 20, 108, 64
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

local function modeSegmentBounds(index)
    local innerX, innerY = MODE_X + 8, MODE_Y + 29
    local segmentWidth = (MODE_W - 16) / #modes
    return innerX + (index - 1) * segmentWidth, innerY, segmentWidth, MODE_H - 37
end

local function drawModeSelector()
    setColor(colors.panel, 0.96)
    love.graphics.rectangle("fill", MODE_X, MODE_Y, MODE_W, MODE_H, 5, 5)
    setColor(colors.border, 0.78)
    love.graphics.rectangle("line", MODE_X + 0.5, MODE_Y + 0.5, MODE_W - 1, MODE_H - 1, 5, 5)
    setColor(canChangeMode() and colors.text or colors.muted)
    love.graphics.print("MODE", MODE_X + 12, MODE_Y + 8)

    for index, option in ipairs(modes) do
        local x, y, width, height = modeSegmentBounds(index)
        local selected = option.id == game.mode
        setColor(selected and option.color or colors.background, selected and 0.88 or 0.72)
        love.graphics.rectangle("fill", x, y, width, height, 3, 3)
        setColor(selected and option.color or colors.border, selected and 1 or 0.55)
        love.graphics.rectangle("line", x + 0.5, y + 0.5, width - 1, height - 1, 3, 3)
        setColor(selected and colors.background or colors.muted)
        love.graphics.printf(option.label, x, y + 7, width, "center")
    end
end

local function modeAtPoint(x, y)
    for index, option in ipairs(modes) do
        local segmentX, segmentY, width, height = modeSegmentBounds(index)
        if x >= segmentX and x <= segmentX + width and y >= segmentY and y <= segmentY + height then
            return option.id
        end
    end
end

local function drawHeader()
    setColor(colors.text)
    love.graphics.print("LUA LÖVE SNAKE", 42, 28)
    drawModeSelector()
    drawStatBox("SCORE", game.score, 632, colors.gold, colors.gold)
    drawStatBox("BEST", activeBestScore(), 758, colors.snakeDark, colors.text)
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
        subtitle = "Press Enter or a direction key"
    elseif game.state == "paused" then
        title = "PAUSED"
        subtitle = game.pausedForFocus and "Click the game window to continue" or "Press P or Esc to continue"
    elseif game.state == "confirm-mode" then
        title = "SWITCH TO " .. string.upper(game.pendingMode) .. "?"
        subtitle = "This run will end and its score will not count."
        prompt = "Y  RESTART     N  CANCEL"
    elseif game.state == "won" then
        title = "BOARD CLEARED"
        subtitle = "Press Enter to play again"
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
    love.graphics.print("WASD / ARROWS  TURN    P / ESC  PAUSE    M  MODE", 30, BASE_H - 33)

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
    love.graphics.printf(game.inputEvent, 410, BASE_H - 43, 520, "right")
    setColor(colors.muted)
    love.graphics.printf(held, 410, BASE_H - 22, 520, "right")
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    -- Game controls should not enter Windows IME composition mode.
    love.keyboard.setTextInput(false)
    love.math.setRandomSeed(os.time())
    resetGame()
end

function love.update(dt)
    game.pulse = math.max(0, game.pulse - dt * 3)
    if game.state ~= "playing" then
        return
    end
    game.timer = game.timer + dt
    while game.timer >= game.stepInterval do
        game.timer = game.timer - game.stepInterval
        step()
        if game.state ~= "playing" then
            break
        end
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
    if game.state == "confirm-mode" then
        if key == "y" or scancode == "y" then
            confirmModeChange()
            game.inputEvent = "MODE  " .. string.upper(game.mode)
        elseif key == "n" or scancode == "n" then
            cancelModeChange()
            game.inputEvent = "MODE  CANCELLED"
        end
        return
    end
    if (key == "m" or scancode == "m") and canChangeMode() then
        toggleMode()
        game.inputEvent = game.state == "confirm-mode"
            and "MODE  CONFIRM " .. string.upper(game.pendingMode)
            or "MODE  " .. string.upper(game.mode)
        return
    end
    -- Scancodes keep WASD stable across keyboard layouts and input methods.
    local direction = keyDirections[scancode] or keyDirections[key]
    if direction then
        queueDirection(direction)
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

function love.mousepressed(x, y, button)
    game.inputEvent = "MOUSE button=" .. tostring(button)
    if button == 1 and canChangeMode() then
        local scale, offsetX, offsetY = scaleTransform()
        local mode = modeAtPoint((x - offsetX) / scale, (y - offsetY) / scale)
        if mode and requestMode(mode) then
            game.inputEvent = game.state == "confirm-mode"
                and "MODE  CONFIRM " .. string.upper(game.pendingMode)
                or "MODE  " .. string.upper(game.mode)
            return
        end
    end
    if game.state == "title" or game.state == "over" or game.state == "won" then
        startGame()
    end
end
