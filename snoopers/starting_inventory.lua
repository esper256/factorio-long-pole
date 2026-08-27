-- Records the Freeplay starter inventory as harvested, because Factorio does
-- not include these items in its production statistics.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

function M.on_init()
  if game.tick ~= 0 then
    return
  end

  local runtime_state = long_pole_runtime_state.get()
  local nauvis = game_state.surface(runtime_state.ledger, "nauvis")
  nauvis:record_products_harvested({
    ["wood"] = 1,
    ["stone-furnace"] = 1,
    ["burner-mining-drill"] = 1,
    ["iron-plate"] = 8,
    ["firearm-magazine"] = 10
  })
end

return M
