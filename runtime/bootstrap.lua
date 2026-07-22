-- Runtime event composition. Feature behavior belongs in feature controllers;
-- this file only makes Factorio's event map obvious in one place.
local debug_window_controller = require("runtime.debug_window_controller")
local snooper_master = require("snoopers.snooper_master")

local M = {}

local function on_init()
  debug_window_controller.on_init()
  snooper_master.on_init()
end

function M.install(script_root)
  script_root.on_init(on_init)
  script_root.on_configuration_changed(debug_window_controller.on_configuration_changed)
  script_root.on_event(defines.events.on_player_created, debug_window_controller.on_player_created)
  script_root.on_event(defines.events.on_player_joined_game, debug_window_controller.on_player_joined_game)
  script_root.on_event("long-pole-toggle-debug-window", debug_window_controller.on_toggle_debug_window)
  script_root.on_nth_tick(60, debug_window_controller.on_second_tick)
  snooper_master.install(script_root)
end

return M
