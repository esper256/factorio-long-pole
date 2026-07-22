-- Coordinates the active-plan state, library loading, and gameplay HUD.
local speedrun_hud = require("hud.speedrun_hud")
local speedrun_attempts = require("runtime_state.speedrun_attempts")
local blueprint_book_plan_loader = require("storage.blueprint_book_plan_loader")
local construction_progress = require("progress_analysis.construction_progress")
local research_progress = require("progress_analysis.research_progress")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

local function auto_load_first_plan(player)
  if speedrun_attempts.get(player.index) then
    return
  end
  local player_setting = settings.get_player_settings(player.index)["long-pole-auto-load-first-plan"]
  if player_setting and not player_setting.value then
    return
  end

  local plan, library_book_index = blueprint_book_plan_loader.load_first_library_book_for_player(player)
  if plan then
    speedrun_attempts.start(player.index, plan, library_book_index, long_pole_runtime_state.get().debug_game_state)
  end
end

local function refresh(player)
  local attempt = speedrun_attempts.get(player.index)
  if not attempt then
    speedrun_hud.refresh(player, nil)
    return
  end

  local state = long_pole_runtime_state.get().debug_game_state
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

  speedrun_attempts.start(player.index, plan, library_book_index, long_pole_runtime_state.get().debug_game_state)
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
      attempt:mark_current_split_done(game.tick, long_pole_runtime_state.get().debug_game_state)
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

  speedrun_attempts.start(player.index, plan, library_book_index, long_pole_runtime_state.get().debug_game_state)
  refresh(player)
end

return M
