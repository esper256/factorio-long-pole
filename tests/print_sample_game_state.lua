local pretty_printer = require("test_support.game_state_pretty_printer")

local state = dofile("test_data/sample_game_state.lua")

print(pretty_printer.render(state))
