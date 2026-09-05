package.path = "./?.lua;./?/init.lua;" .. package.path

local Command = require("src.championship.command")

os.exit(Command.main(arg or {}))
