-- Records entities completed by construction robots and the item each build
-- consumes. Robot construction has its own Factorio event and item-stack shape.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

M.event_names = {
  "on_robot_built_entity"
}

function M.on_event(event)
  if event.entity.type == "entity-ghost" then
    return
  end

  local runtime_state = long_pole_runtime_state.get()
  local surface = game_state.surface(runtime_state.debug_game_state, event.entity.surface.name)

  surface:record_placed_entities({
    [event.entity.name] = 1
  })
  surface:record_products_placed({
    [event.stack.name] = event.stack.count
  })
end

return M
