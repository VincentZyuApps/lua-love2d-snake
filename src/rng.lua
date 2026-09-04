local Rng = {}
Rng.__index = Rng

local MODULUS = 2147483647
local MULTIPLIER = 16807
local QUOTIENT = 127773
local REMAINDER = 2836

local function hashSeed(seedText, stream)
    local state = (stream or 1) % (MODULUS - 1)
    for index = 1, #seedText do
        state = (state * 131 + seedText:byte(index)) % (MODULUS - 1)
    end
    return state + 1
end

function Rng.new(seedText, stream)
    return setmetatable({ state = hashSeed(tostring(seedText), stream) }, Rng)
end

function Rng:next()
    local high = math.floor(self.state / QUOTIENT)
    local low = self.state % QUOTIENT
    local value = MULTIPLIER * low - REMAINDER * high
    self.state = value > 0 and value or value + MODULUS
    return self.state
end

function Rng:integer(maximum)
    assert(maximum and maximum >= 1, "maximum must be at least 1")
    return self:next() % maximum + 1
end

function Rng:number()
    return (self:next() - 1) / (MODULUS - 1)
end

return Rng
