-- Runtime event composition. Feature behavior belongs in feature controllers;
-- this file only makes Factorio's event map obvious in one place.
local debug_window_controller = require("runtime.debug_window_controller")
local snooper_master = require("snoopers.snooper_master")
local speedrun_hud_controller = require("runtime.speedrun_hud_controller")
local speedrun_attempt = require("speedrun_plan.attempt")
local speedrun_plan = require("speedrun_plan.plan")

local M = {}

local function on_init()
  debug_window_controller.on_init()
  speedrun_hud_controller.on_init()
  snooper_master.on_init()
end

local function on_configuration_changed(event)
  debug_window_controller.on_configuration_changed(event)
  speedrun_hud_controller.on_configuration_changed(event)
end

local function on_player_created(event)
  debug_window_controller.on_player_created(event)
  speedrun_hud_controller.on_player_created(event)
end

local function on_player_joined_game(event)
  debug_window_controller.on_player_joined_game(event)
  speedrun_hud_controller.on_player_joined_game(event)
end

local function on_second_tick(event)
  -- Reconcile before rendering so the visible data is fresh for this interval.
  snooper_master.on_second_tick(event)
  debug_window_controller.on_second_tick(event)
  speedrun_hud_controller.on_second_tick(event)
end

function M.install(script_root)
  speedrun_plan.register_metatables(script_root)
  speedrun_attempt.register_metatable(script_root)
  script_root.on_init(on_init)
  script_root.on_configuration_changed(on_configuration_changed)
  script_root.on_event(defines.events.on_player_created, on_player_created)
  script_root.on_event(defines.events.on_player_joined_game, on_player_joined_game)
  script_root.on_event(defines.events.on_gui_click, speedrun_hud_controller.on_gui_click)
  script_root.on_event("long-pole-toggle-debug-window", debug_window_controller.on_toggle_debug_window)
  script_root.on_nth_tick(60, on_second_tick)
  snooper_master.install(script_root)
end

return M
