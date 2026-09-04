local runTests = false
for _, argument in ipairs(arg or {}) do
    runTests = runTests or argument == "--run-tests"
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
else
    require("src.app")
end
