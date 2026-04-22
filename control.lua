local split_viewer = require("gui.split_viewer")
local plan_editor = require("gui.plan_editor")
local plan_storage = require("plan_storage")
local progress_snooper = require("progress_snooper")
local tracker = require("split_tracker")
local starting_loose_stock = require("util.starting_loose_stock")

local runtime_flags = {}
do
  local ok, loaded_flags = pcall(require, "test_support.runtime_flags")
  if ok and type(loaded_flags) == "table" then
    runtime_flags = loaded_flags
  end
end

local PROGRESS_SNOOPER_EVENT_IDS = {
  on_built_entity = defines.events.on_built_entity,
  on_pre_player_crafted_item = defines.events.on_pre_player_crafted_item,
  on_player_crafted_item = defines.events.on_player_crafted_item,
  on_player_cancelled_crafting = defines.events.on_player_cancelled_crafting,
  on_player_mined_entity = defines.events.on_player_mined_entity,
  on_robot_built_entity = defines.events.on_robot_built_entity,
  on_robot_mined_entity = defines.events.on_robot_mined_entity
}

local AUTO_IMPORT_FIRST_PLAN_SETTING = "long-pole-auto-import-first-plan-on-new-game"
local AUTO_IMPORT_RETRY_WINDOW_TICKS = 600

local function refresh_split_viewer_for_player(player)
  if not (player and player.valid) then
    return
  end

  split_viewer.refresh(player, storage)
end

local function refresh_plan_editor_for_player(player)
  if not (player and player.valid) then
    return
  end

  plan_editor.refresh(player, storage)
end

local function refresh_player(player)
  refresh_split_viewer_for_player(player)
  refresh_plan_editor_for_player(player)
end

local function refresh_all_players(refresh_editor)
  for _, player in pairs(game.players) do
    refresh_split_viewer_for_player(player)
    if refresh_editor then
      refresh_plan_editor_for_player(player)
    end
  end
end

local function initialize_state()
  tracker.init(storage)
  progress_snooper.init(storage)
  storage.plan_name = storage.plan_name or nil
  storage.plan_id = storage.plan_id or nil
  storage.plan_source = storage.plan_source or "none"
  storage.pending_auto_import_by_player = storage.pending_auto_import_by_player or {}
end

local function on_runtime_initialized()
  initialize_state()
  refresh_all_players(true)
end

local function maybe_grant_starting_loose_stock(player)
  starting_loose_stock.grant_once(storage, player)
end

local function should_auto_import_plan_on_new_game()
  local settings_root = settings and settings.global
  local setting = settings_root and settings_root[AUTO_IMPORT_FIRST_PLAN_SETTING]
  return setting and setting.value == true
end

local function has_initialized_plan_state(state)
  return state.plan_source ~= "none" or state.plan_id ~= nil or (state.splits and #state.splits > 0)
end

local function clear_pending_auto_import(player_index)
  if player_index == nil then
    return
  end

  storage.pending_auto_import_by_player[player_index] = nil
end

local function schedule_auto_import_for_player(player_index, tick)
  storage.pending_auto_import_by_player[player_index] = (tick or 0) + AUTO_IMPORT_RETRY_WINDOW_TICKS
end

local function maybe_auto_import_plan_for_player(player)
  if not (player and player.valid) then
    clear_pending_auto_import(player and player.index or nil)
    return
  end

  if not should_auto_import_plan_on_new_game() then
    clear_pending_auto_import(player.index)
    return
  end

  if has_initialized_plan_state(storage) then
    clear_pending_auto_import(player.index)
    return
  end

  local ok = plan_storage.import_first_plan_from_blueprint_library(player, storage, game)
  if not ok then
    return
  end

  clear_pending_auto_import(player.index)
end

local function process_pending_auto_imports(current_tick)
  for player_index, expires_at_tick in pairs(storage.pending_auto_import_by_player or {}) do
    if expires_at_tick < current_tick then
      clear_pending_auto_import(player_index)
    else
      maybe_auto_import_plan_for_player(game.get_player(player_index))
    end
  end
end

local function run_gui_smoke_actions(player)
  if not runtime_flags.gui_smoke_open_and_close_editor then
    return
  end

  storage.gui_smoke_actions_completed = storage.gui_smoke_actions_completed or {}
  if storage.gui_smoke_actions_completed[player.index] then
    return
  end

  if not plan_storage.has_active_plan(storage) then
    plan_storage.create_new_plan(storage)
  end
  plan_editor.open(player, storage)
  plan_editor.close(player)
  storage.gui_smoke_actions_completed[player.index] = true
end

script.on_init(on_runtime_initialized)
script.on_configuration_changed(on_runtime_initialized)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  maybe_grant_starting_loose_stock(player)
  schedule_auto_import_for_player(event.player_index, event.tick)
  maybe_auto_import_plan_for_player(player)
  refresh_player(player)
  run_gui_smoke_actions(player)
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  schedule_auto_import_for_player(event.player_index, event.tick)
  maybe_auto_import_plan_for_player(game.get_player(event.player_index))
end)

script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
  refresh_split_viewer_for_player(game.get_player(event.player_index))
end)

script.on_nth_tick(30, function()
  process_pending_auto_imports(game.tick)
  progress_snooper.poll(storage, game)
  -- The split viewer is live progress UI; the editor should only rebuild after editor actions.
  refresh_all_players(false)
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

  if split_viewer.handle_click(player, storage, element, event) then
    refresh_split_viewer_for_player(player)
    return
  end

  local plan_editor_result = plan_editor.handle_click(player, storage, element, event)
  if plan_editor_result == "refresh-split-viewer" then
    split_viewer.refresh(player, storage)
    return
  end

  if plan_editor_result == "handled" then
    return
  end

  if plan_editor_result then
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

script.on_event(defines.events.on_gui_elem_changed, function(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if plan_editor.handle_elem_changed(player, storage, element) then
    split_viewer.refresh(player, storage)
    plan_editor.refresh(player, storage)
  end
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  plan_editor.handle_value_changed(player, storage, element)
end)

script.on_event(defines.events.on_gui_confirmed, function(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local plan_editor_result = plan_editor.handle_confirmed(player, storage, element)
  if plan_editor_result == "handled" then
    return
  end

  if plan_editor_result then
    refresh_player(player)
  end
end)

for _, event_name in ipairs(progress_snooper.subscribed_event_names()) do
  local event_id = PROGRESS_SNOOPER_EVENT_IDS[event_name]
  if event_id then
    script.on_event(event_id, function(event)
      progress_snooper.dispatch(storage, event_name, event)
    end)
  end
end
