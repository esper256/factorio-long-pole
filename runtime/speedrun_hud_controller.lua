-- Coordinates the active-plan state, library loading, and gameplay HUD.
local speedrun_hud = require("hud.speedrun_hud")
local speedrun_attempts = require("runtime_state.speedrun_attempts")
local blueprint_book_plan_loader = require("storage.blueprint_book_plan_loader")
local construction_progress = require("progress_analysis.construction_progress")
local next_split_construction_progress = require("progress_analysis.next_split_construction_progress")
local extra_item_progress = require("progress_analysis.extra_item_progress")
local research_progress = require("progress_analysis.research_progress")
local split_completion = require("progress_analysis.split_completion")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")
local current_split_quickbar = require("runtime.current_split_quickbar")

local M = {}
local AUTO_LOAD_SETTING_NAME = "long-pole-auto-load-first-plan"
local AUTO_ADVANCE_SETTING_NAME = "long-pole-auto-advance-split"
local CURRENT_SPLIT_QUICKBAR_SETTING_NAME = "long-pole-put-current-split-in-quickbar"
local auto_load_errors_by_player = {}

local function current_split_quickbar_enabled(player)
  local setting = settings.get_player_settings(player.index)[CURRENT_SPLIT_QUICKBAR_SETTING_NAME]
  return setting and setting.value
end

local function start_attempt(player, plan, library_book_index)
  local attempt = speedrun_attempts.start(
    player.index,
    plan,
    library_book_index,
    long_pole_runtime_state.get().debug_game_state
  )
  if current_split_quickbar_enabled(player) then
    current_split_quickbar.update(player, attempt)
  end
  return attempt
end

local function advance_attempt(player, attempt)
  attempt:mark_current_split_done(game.tick, long_pole_runtime_state.get().debug_game_state)
  if current_split_quickbar_enabled(player) then
    current_split_quickbar.update(player, attempt)
  end
end

local function auto_load_first_plan(player)
  if speedrun_attempts.get(player.index) then
    return
  end
  local player_setting = settings.get_player_settings(player.index)[AUTO_LOAD_SETTING_NAME]
  if player_setting and not player_setting.value then
    return
  end
  if auto_load_errors_by_player[player.index] then
    return
  end

  local plan, library_book_index, load_error = blueprint_book_plan_loader.load_first_library_book_for_player(player)
  if plan then
    start_attempt(player, plan, library_book_index)
  elseif load_error then
    -- A malformed marked book has already printed its actionable error. Do not
    -- repeat it every second; a reload or setting change retries the library.
    auto_load_errors_by_player[player.index] = load_error
  end
end

local function view_for_attempt(attempt, state)
  attempt:ensure_current_split_started(state)
  local view = attempt:hud_view(game.tick)
  local split = attempt:current_split()
  if split then
    view.construction_progress = construction_progress.for_split(
      split,
      state,
      attempt.split_start_placed_product_counts
    )
    view.research_progress = research_progress.for_split(split, state, game.forces.player)
    view.extra_item_progress = extra_item_progress.for_split(split, state)

    local next_split = attempt.plan:split_at(attempt.current_split_index + 1)
    if next_split and #next_split.placement_item_names > 0 then
      view.next_split_construction_progress = next_split_construction_progress.for_splits(
        split,
        next_split,
        state,
        attempt.split_start_placed_product_counts
      )
    end
  end
  return view
end

local function auto_advance_enabled(player)
  local setting = settings.get_player_settings(player.index)[AUTO_ADVANCE_SETTING_NAME]
  return setting and setting.value
end

local function refresh(player)
  local attempt = speedrun_attempts.get(player.index)
  if not attempt then
    speedrun_hud.refresh(player, nil)
    return
  end

  local state = long_pole_runtime_state.get().debug_game_state
  local view = view_for_attempt(attempt, state)
  if auto_advance_enabled(player)
    and view.next_split_label ~= nil
    and split_completion.is_complete({
      view.construction_progress,
      view.research_progress,
      view.extra_item_progress
    }) then
    advance_attempt(player, attempt)
    view = view_for_attempt(attempt, state)
  end
  speedrun_hud.refresh(player, view)
end

function M.on_init()
  for _, player in pairs(game.players) do
    auto_load_first_plan(player)
    refresh(player)
  end
end

function M.on_configuration_changed(_event)
  for _, player in pairs(game.players) do
    auto_load_first_plan(player)
    refresh(player)
  end
end

function M.on_player_created(event)
  local player = game.get_player(event.player_index)
  auto_load_first_plan(player)
  refresh(player)
end

function M.on_player_joined_game(event)
  local player = game.get_player(event.player_index)
  auto_load_first_plan(player)
  refresh(player)
end

function M.on_second_tick(_event)
  for _, player in pairs(game.players) do
    -- Player blueprint records may become available after the player lifecycle
    -- callbacks. Retrying here is safe: active attempts return immediately,
    -- and unmarked library books are inspected by label only.
    auto_load_first_plan(player)
    refresh(player)
  end
end

function M.on_runtime_mod_setting_changed(event)
  if event.setting ~= AUTO_LOAD_SETTING_NAME
    and event.setting ~= AUTO_ADVANCE_SETTING_NAME
    and event.setting ~= CURRENT_SPLIT_QUICKBAR_SETTING_NAME then
    return
  end

  local player = game.get_player(event.player_index)
  if player then
    if event.setting == AUTO_LOAD_SETTING_NAME then
      auto_load_errors_by_player[player.index] = nil
      auto_load_first_plan(player)
    elseif event.setting == CURRENT_SPLIT_QUICKBAR_SETTING_NAME and current_split_quickbar_enabled(player) then
      local attempt = speedrun_attempts.get(player.index)
      if attempt then
        current_split_quickbar.update(player, attempt)
      end
    end
    refresh(player)
  end
end

-- Step 9 will use this same entry point for automatic first-plan loading.
function M.load_library_plan(player, library_book_index)
  local book = player.blueprints[library_book_index]
  local plan, load_error = blueprint_book_plan_loader.load_book_for_player(player, book)
  if not plan then
    return nil, load_error
  end

  start_attempt(player, plan, library_book_index)
  refresh(player)
  return plan
end

function M.on_gui_click(event)
  if not event.element.valid then
    return
  end

  local player = game.get_player(event.player_index)
  if event.element.name == speedrun_hud.advance_split_button_name() then
    local attempt = speedrun_attempts.get(player.index)
    if attempt then
      advance_attempt(player, attempt)
      refresh(player)
    end
    return
  end
  if event.element.name ~= speedrun_hud.next_plan_button_name() then
    return
  end

  local attempt = speedrun_attempts.get(player.index)
  local after_index = attempt and attempt.library_book_index or 0
  local plan, library_book_index = blueprint_book_plan_loader.load_next_library_book_for_player(player, after_index)
  if not plan then
    return
  end

  start_attempt(player, plan, library_book_index)
  refresh(player)
end

return M
