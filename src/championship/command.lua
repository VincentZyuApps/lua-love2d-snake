local Arguments = require("src.championship.arguments")
local Reports = require("src.championship.reports")
local Runner = require("src.championship.runner")

local Command = {}

function Command.main(argv)
    local ok, exitCode = pcall(function()
        local config = Arguments.parse(argv)
        if config.help then
            print(Arguments.usage())
            return 0
        end
        local document, errors
        if config.mergeManifest then
            document = Reports.mergeManifest(config.mergeManifest)
            errors = 0
        else
            local games
            games, errors = Runner.run(config, function(game, count)
                print(string.format("[%d] %s %s %s #%d: %s", count, game.size,
                    game.edge, game.algorithm, game.run, game.outcome))
            end)
            document = Reports.build(config, games)
        end
        Reports.write(config.outputDir, document)
        print("Reports written to " .. config.outputDir)
        return errors > 0 and 1 or 0
    end)
    if not ok then
        io.stderr:write(tostring(exitCode) .. "\n")
        return 2
    end
    return exitCode
end

return Command
