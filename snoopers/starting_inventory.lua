-- Records the default Freeplay inventory once, when a new game begins.
--
-- on_init also runs when a mod is first added to an existing save, so the tick
-- guard is essential: only tick zero is the beginning of a new game.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

function M.on_init()
  if game.tick ~= 0 then
    return
  end

  local runtime_state = long_pole_runtime_state.get()
  local nauvis = game_state.surface(runtime_state.debug_game_state, "nauvis")
  nauvis:record_products_produced({
    wood = 1,
    ["stone-furnace"] = 1,
    ["burner-mining-drill"] = 1,
    ["iron-plate"] = 8,
    ["firearm-magazine"] = 10
  })
end

return M
