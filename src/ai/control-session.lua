local ControlSession = {}
ControlSession.__index = ControlSession

function ControlSession.new(algorithm, world, aiRng)
    local self = setmetatable({
        algorithm = algorithm,
        aiRng = aiRng,
        override = nil,
    }, ControlSession)
    self:reset(world)
    return self
end

function ControlSession:reset(world)
    self.override = nil
    self.memory = self.algorithm.reset(world, { aiRng = self.aiRng }) or {}
end

function ControlSession:setAlgorithm(algorithm, world)
    self.algorithm = algorithm
    self:reset(world)
end

function ControlSession:queueOverride(directionName)
    self.override = directionName
end

function ControlSession:chooseDirection(world, controlMode, context)
    local directionName = self.algorithm.chooseDirection(world, self.memory, context) or world.direction
    local intervened = false
    if controlMode == "hybrid" and self.override then
        intervened = self.override ~= directionName
        directionName = self.override
        self.override = nil
        if intervened then
            self:reset(world)
        end
    end
    return directionName, intervened
end

return ControlSession
