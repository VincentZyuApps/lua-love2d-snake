local BoardConfig = require("src.board")

local Constants = {
    BASE_WIDTH = 960,
    BASE_HEIGHT = 720,
    CELL_SIZE = 24,
    COLS = BoardConfig.DEFAULT_COLS,
    ROWS = BoardConfig.DEFAULT_ROWS,
    BOARD_Y = 132,
    BOARD_AREA_X = 120,
    BOARD_AREA_Y = 132,
    BOARD_AREA_WIDTH = 720,
    BOARD_AREA_HEIGHT = 504,
    MAX_STEPS_PER_FRAME = 2048,
    AI_BUDGET_SECONDS = 0.010,
    DEFAULT_SPEED_INDEX = 2,
    SPEED_PRESETS = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 25, 50, 100, 1000, 10000 },
    EDGE_MODES = { "walls", "wrap" },
    CONTROL_MODES = { "manual", "auto", "hybrid" },
}

function Constants.stepInterval(score, multiplier)
    local currentCurve = math.max(0.06, 0.145 - score * 0.0035)
    return currentCurve * 2 / multiplier
end

return Constants
