-- Records items granted by Factorio's on_player_mined_item event.
--
-- Disabled: production statistics already include hand-mined and drill-mined
-- ore (PRODUCT.md §14). Enabling this alongside the graph double-counts.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

M.event_names = {
  "on_player_mined_item"
}

function M.on_event(event)
  local player = game.get_player(event.player_index)
  local runtime_state = long_pole_runtime_state.get()
  local surface = game_state.surface(runtime_state.ledger, player.surface.name)

  surface:record_products_produced({
    [event.item_stack.name] = event.item_stack.count
  })
end

return M
