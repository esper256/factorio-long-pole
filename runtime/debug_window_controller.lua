-- Runtime behavior for the temporary debug window. Keeping this feature's
-- state access and GUI behavior here leaves bootstrap as event composition.
local debug_state_panel = require("hud.debug_state_panel")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

local function refresh_player_debug_panel(player)
  local runtime_state = long_pole_runtime_state.get()
  debug_state_panel.refresh(player, runtime_state.debug_game_state)
end

function M.on_init()
  long_pole_runtime_state.get()
end

function M.on_configuration_changed(_event)
  long_pole_runtime_state.get()

  for _, player in pairs(game.players) do
    refresh_player_debug_panel(player)
  end
end

function M.on_player_created(event)
  refresh_player_debug_panel(game.get_player(event.player_index))
end

function M.on_player_joined_game(event)
  refresh_player_debug_panel(game.get_player(event.player_index))
end

function M.on_toggle_debug_window(event)
  local runtime_state = long_pole_runtime_state.get()
  debug_state_panel.toggle(game.get_player(event.player_index), runtime_state.debug_game_state)
end

return M
