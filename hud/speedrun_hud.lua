-- Compact gameplay HUD for the active speedrun plan. It deliberately knows
-- only about presentation; runtime state and library traversal stay elsewhere.
local M = {}

local HUD_NAME = "long_pole_speedrun_hud"
local HEADER_NAME = "speedrun_header"
local PLAN_NAME = "active_speedrun_name"
local PREVIOUS_NAME = "previous_split"
local CURRENT_NAME = "current_split"
local ADVANCE_SPLIT_BUTTON_NAME = "long_pole_advance_split"
local NEXT_PLAN_BUTTON_NAME = "long_pole_next_plan"

local function game_time_caption(tick)
  local total_seconds = math.floor(tick / 60)
  local hours = math.floor(total_seconds / 3600)
  local minutes = math.floor(total_seconds % 3600 / 60)
  local seconds = total_seconds % 60
  return ("%d:%02d:%02d"):format(hours, minutes, seconds)
end

local function build(player)
  local hud = player.gui.left.add({
    type = "flow",
    name = HUD_NAME,
    direction = "vertical"
  })

  local header = hud.add({
    type = "flow",
    name = HEADER_NAME,
    direction = "horizontal"
  })
  header.add({
    type = "label",
    name = PLAN_NAME
  })
  local next_plan_button = header.add({
    type = "sprite-button",
    name = NEXT_PLAN_BUTTON_NAME,
    sprite = "utility/right_arrow",
    tooltip = "Load the next [LP] blueprint book in your library."
  })
  next_plan_button.style.width = 24
  next_plan_button.style.height = 24

  hud.add({
    type = "label",
    name = PREVIOUS_NAME
  })
  hud.add({
    type = "label",
    name = CURRENT_NAME
  })
  hud.add({
    type = "button",
    name = ADVANCE_SPLIT_BUTTON_NAME,
    style = "transparent_button",
    tooltip = "Mark the current split complete."
  })

  return hud
end

function M.next_plan_button_name()
  return NEXT_PLAN_BUTTON_NAME
end

function M.advance_split_button_name()
  return ADVANCE_SPLIT_BUTTON_NAME
end

function M.is_visible(player)
  return player.gui.left[HUD_NAME] ~= nil
end

function M.hide(player)
  local existing = player.gui.left[HUD_NAME]
  if existing then
    existing.destroy()
  end
end

function M.refresh(player, view)
  if not (player and player.valid) then
    return
  end

  local hud = player.gui.left[HUD_NAME] or build(player)
  local header = hud[HEADER_NAME]
  local plan_name = header[PLAN_NAME]
  local previous = hud[PREVIOUS_NAME]
  local current = hud[CURRENT_NAME]
  local advance_split_button = hud[ADVANCE_SPLIT_BUTTON_NAME]

  if not view then
    plan_name.caption = "No active speedrun"
    previous.visible = false
    current.visible = false
    advance_split_button.visible = false
    return
  end

  plan_name.caption = view.plan_label
  current.visible = true

  if view.previous_split_label then
    previous.visible = true
    previous.caption = view.previous_split_label
      .. "  " .. game_time_caption(view.previous_split_finished_tick)
  else
    previous.visible = false
  end

  current.caption = view.current_split_label .. "  " .. game_time_caption(view.game_tick)
  advance_split_button.visible = view.next_split_label ~= nil
  advance_split_button.caption = view.next_split_label or ""
end

return M
