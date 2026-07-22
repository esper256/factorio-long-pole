-- Compact gameplay HUD for the active speedrun plan. It deliberately knows
-- only about presentation; runtime state and library traversal stay elsewhere.
local M = {}

local FRAME_NAME = "long_pole_speedrun_hud"
local PREVIOUS_NAME = "previous_split"
local CURRENT_NAME = "current_split"
local NEXT_NAME = "next_split"
local NEXT_PLAN_BUTTON_NAME = "long_pole_next_plan"

local function game_time_caption(tick)
  local total_seconds = math.floor(tick / 60)
  local hours = math.floor(total_seconds / 3600)
  local minutes = math.floor(total_seconds % 3600 / 60)
  local seconds = total_seconds % 60
  return ("%d:%02d:%02d"):format(hours, minutes, seconds)
end

local function build(player)
  local frame = player.gui.left.add({
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical",
    caption = "Long Pole"
  })
  frame.style.minimal_width = 220

  frame.add({
    type = "label",
    name = PREVIOUS_NAME
  })
  frame.add({
    type = "label",
    name = CURRENT_NAME
  })
  frame.add({
    type = "label",
    name = NEXT_NAME
  })
  frame.add({
    type = "button",
    name = NEXT_PLAN_BUTTON_NAME,
    caption = "Next plan",
    tooltip = "Load the next [LP] blueprint book in your library."
  })

  return frame
end

function M.next_plan_button_name()
  return NEXT_PLAN_BUTTON_NAME
end

function M.is_visible(player)
  return player.gui.left[FRAME_NAME] ~= nil
end

function M.hide(player)
  local existing = player.gui.left[FRAME_NAME]
  if existing then
    existing.destroy()
  end
end

function M.refresh(player, view)
  if not (player and player.valid) then
    return
  end
  if not view then
    M.hide(player)
    return
  end

  local frame = player.gui.left[FRAME_NAME] or build(player)
  local previous = frame[PREVIOUS_NAME]
  local current = frame[CURRENT_NAME]
  local next_split = frame[NEXT_NAME]

  if view.previous_split_label then
    previous.visible = true
    previous.caption = "Previous: " .. view.previous_split_label
      .. "  " .. game_time_caption(view.previous_split_finished_tick)
  else
    previous.visible = false
  end

  current.caption = "Current: " .. view.current_split_label
    .. "  " .. game_time_caption(view.game_tick)
  next_split.caption = "Next: " .. (view.next_split_label or "—")
end

return M
