local Storage = {}
Storage.__index = Storage

local FILE_NAME = "lua-love2d-snake-stats.json"

local function dirname(path)
    return path and path:match("^(.*)[/\\][^/\\]+$") or nil
end

local function joinPath(directory, filename)
    local separator = package.config:sub(1, 1)
    return directory .. separator .. filename
end

local function fileExists(path)
    local file = io.open(path, "rb")
    if not file then
        return false
    end
    file:close()
    return true
end

local function readFile(path)
    local file, errorMessage = io.open(path, "rb")
    if not file then
        return nil, errorMessage
    end
    local content = file:read("*a")
    file:close()
    return content
end

local function probeWritable(directory)
    if not directory or directory == "" then
        return false
    end
    local probePath = joinPath(directory, ".lua-love2d-snake-write-test")
    local file = io.open(probePath, "wb")
    if not file then
        return false
    end
    file:write("ok")
    file:close()
    os.remove(probePath)
    return true
end

local function portableDirectory()
    if love.filesystem.isFused() then
        local appImage = os.getenv("APPIMAGE")
        if appImage and appImage ~= "" then
            return dirname(appImage)
        end
        if love.filesystem.getExecutablePath then
            local executable = love.filesystem.getExecutablePath()
            local macParent = executable and executable:match("^(.*)[/\\][^/\\]+%.app[/\\]Contents[/\\]MacOS")
            return macParent or dirname(executable)
        end
    end

    local source = love.filesystem.getSource()
    if source and source:lower():match("%.love$") then
        return dirname(source)
    end
    return source
end

local function atomicWrite(path, content)
    local temporary = path .. ".tmp"
    local backup = path .. ".bak"
    local file, errorMessage = io.open(temporary, "wb")
    if not file then
        return false, errorMessage
    end
    local wrote, writeError = file:write(content)
    file:close()
    if not wrote then
        os.remove(temporary)
        return false, writeError
    end

    os.remove(backup)
    local hadExisting = fileExists(path)
    if hadExisting then
        local backedUp, backupError = os.rename(path, backup)
        if not backedUp then
            os.remove(temporary)
            return false, backupError
        end
    end

    local replaced, replaceError = os.rename(temporary, path)
    if not replaced then
        if hadExisting then
            os.rename(backup, path)
        end
        os.remove(temporary)
        return false, replaceError
    end
    os.remove(backup)
    return true
end

function Storage.new(options)
    options = options or {}
    local portablePath = options.portablePath
    if portablePath == nil then
        local portable = portableDirectory()
        portablePath = portable and joinPath(portable, FILE_NAME) or nil
    end
    local portable = dirname(portablePath)
    if portablePath and (fileExists(portablePath) or probeWritable(portable)) then
        return setmetatable({ mode = "PORTABLE", path = portablePath }, Storage)
    end

    local self = setmetatable({}, Storage)
    self:switchToUserDirectory(options.userPath)
    return self
end

function Storage:switchToUserDirectory(path)
    self.mode = "USER DIRECTORY"
    if path then
        self.path = path
        return true
    end
    local wrote, errorMessage = love.filesystem.write(".lua-love2d-snake-write-test", "ok")
    love.filesystem.remove(".lua-love2d-snake-write-test")
    self.path = joinPath(love.filesystem.getSaveDirectory(), FILE_NAME)
    return wrote, errorMessage
end

function Storage:read()
    if not fileExists(self.path) then
        return nil
    end
    return readFile(self.path)
end

function Storage:write(content)
    return atomicWrite(self.path, content)
end

function Storage:backupCorrupt()
    if not fileExists(self.path) then
        return nil
    end
    local backupPath = self.path .. ".corrupt-" .. os.date("%Y%m%d-%H%M%S")
    local moved = os.rename(self.path, backupPath)
    return moved and backupPath or nil
end

return Storage
