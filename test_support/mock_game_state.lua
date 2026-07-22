-- Small hand-written sample state for tests and temporary debug UI.
local game_state = require("game_state.game_state")

local M = {}

function M.sample()
  local state = game_state.new(21600)
  local nauvis = game_state.surface(state, "nauvis")

  nauvis:record_products_produced({
    ["automation-science-pack"] = 12,
    ["burner-inserter"] = 6,
    ["copper-plate"] = 310,
    ["electronic-circuit"] = 41,
    ["iron-gear-wheel"] = 138,
    ["iron-plate"] = 520,
    ["stone-furnace"] = 5,
    ["transport-belt"] = 94
  })

  nauvis:record_products_consumed({
    ["automation-science-pack"] = 7,
    ["copper-plate"] = 222,
    ["electronic-circuit"] = 15,
    ["iron-gear-wheel"] = 84,
    ["iron-plate"] = 341
  })

  nauvis:record_entities_placed({
    ["burner-inserter"] = 4,
    ["stone-furnace"] = 4,
    ["transport-belt"] = 61
  })

  nauvis:record_products_produced({
    ["crude-oil"] = 4800,
    ["water"] = 10000
  })

  nauvis:record_products_consumed({
    ["crude-oil"] = 1200,
    ["water"] = 3500
  })

  nauvis:record_placed_entities({
    ["assembling-machine-1"] = 2,
    ["burner-mining-drill"] = 3,
    ["lab"] = 1,
    ["stone-furnace"] = 4
  })

  game_state.set_research(
    state,
    "automation",
    false,
    0.7
  )

  game_state.set_research(
    state,
    "logistics",
    false,
    0.2
  )

  return state
end

return M
