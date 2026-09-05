local runTests, runChampionship = false, false
for _, argument in ipairs(arg or {}) do
    runTests = runTests or argument == "--run-tests"
    runChampionship = runChampionship or argument == "--run-championship"
end

if runTests then
    local ok, errorMessage = pcall(function()
        require("tests.test-runner").run()
    end)
    love.load = function()
        if not ok then
            print(errorMessage)
        end
        love.event.quit(ok and 0 or 1)
    end
elseif runChampionship then
    local Command = require("src.championship.command")
    love.load = function()
        love.event.quit(Command.main(arg or {}))
    end
else
    require("src.app")
end
