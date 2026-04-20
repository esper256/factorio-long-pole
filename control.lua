local split_viewer = require("gui.split_viewer")
local plan_editor = require("gui.plan_editor")
local plan_loader = require("plan_loader")
local tracker = require("split_tracker")

local runtime_flags = {}
do
  local ok, loaded_flags = pcall(require, "test_support.runtime_flags")
  if ok and type(loaded_flags) == "table" then
    runtime_flags = loaded_flags
  end
end

local function refresh_player(player)
  if not (player and player.valid) then
    return
  end

  split_viewer.refresh(player, storage)
  plan_editor.refresh(player, storage)
end

local function refresh_all_players()
  for _, player in pairs(game.players) do
    refresh_player(player)
  end
end

local function initialize_state()
  tracker.init(storage)
  plan_loader.ensure_plan_loaded(storage)
  tracker.init(storage)
end

local function on_runtime_initialized()
  initialize_state()
  refresh_all_players()
end

local function run_gui_smoke_actions(player)
  if not runtime_flags.gui_smoke_open_and_close_editor then
    return
  end

  storage.gui_smoke_actions_completed = storage.gui_smoke_actions_completed or {}
  if storage.gui_smoke_actions_completed[player.index] then
    return
  end

  plan_editor.open(player, storage)
  plan_editor.close(player)
  storage.gui_smoke_actions_completed[player.index] = true
end

script.on_init(on_runtime_initialized)
script.on_configuration_changed(on_runtime_initialized)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  refresh_player(player)
  run_gui_smoke_actions(player)
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if split_viewer.handle_click(player, storage, element) then
    refresh_player(player)
    return
  end

  if plan_editor.handle_click(player, storage, element) then
    refresh_player(player)
  end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if plan_editor.handle_text_changed(player, storage, element) then
    split_viewer.refresh(player, storage)
  end
end)

script.on_event(defines.events.on_built_entity, function(event)
  tracker.on_entity_changed(storage, event)
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
  tracker.on_entity_changed(storage, event)
end)
