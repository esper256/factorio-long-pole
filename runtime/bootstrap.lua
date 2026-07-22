-- Runtime event composition. Feature behavior belongs in feature controllers;
-- this file only makes Factorio's event map obvious in one place.
local debug_window_controller = require("runtime.debug_window_controller")

local M = {}

function M.install(script_root)
  script_root.on_init(debug_window_controller.on_init)
  script_root.on_configuration_changed(debug_window_controller.on_configuration_changed)
  script_root.on_event(defines.events.on_player_created, debug_window_controller.on_player_created)
  script_root.on_event(defines.events.on_player_joined_game, debug_window_controller.on_player_joined_game)
  script_root.on_event("long-pole-toggle-debug-window", debug_window_controller.on_toggle_debug_window)
end

return M
