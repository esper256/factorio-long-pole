-- Compact gameplay HUD for the active speedrun plan. It deliberately knows
-- only about presentation; runtime state and library traversal stay elsewhere.
local tri_color_progress_bar = require("hud.tri_color_progress_bar")
local icon_quantity_list = require("hud.icon_quantity_list")

local M = {}

local HUD_NAME = "long_pole_speedrun_hud"
local HEADER_NAME = "speedrun_header"
local PLAN_NAME = "active_speedrun_name"
local PREVIOUS_NAME = "previous_split"
local CURRENT_NAME = "current_split"
local ADVANCE_SPLIT_BUTTON_NAME = "long_pole_advance_split"
local NEXT_PLAN_BUTTON_NAME = "long_pole_next_plan"
local CONSTRUCTION_PROGRESS_NAME = "construction_progress"
local RESEARCH_PROGRESS_NAME = "research_progress"
local EXTRA_ITEM_PROGRESS_NAME = "extra_item_progress"
local CONSTRUCTION_SHORTFALLS_NAME = "construction_shortfalls"
local RESEARCH_SHORTFALLS_NAME = "research_shortfalls"
local EXTRA_ITEM_SHORTFALLS_NAME = "extra_item_shortfalls"
local NEXT_SPLIT_CONSTRUCTION_PROGRESS_NAME = "next_split_construction_progress"
local NEXT_SPLIT_CONSTRUCTION_SHORTFALLS_NAME = "next_split_construction_shortfalls"
local HUD_WIDTH = 192
local function sprite_or_fallback(preferred, fallback)
  if helpers and helpers.is_valid_sprite_path(preferred) then
    return preferred
  end
  return fallback
end

local CONSTRUCTION_ICON = sprite_or_fallback("virtual-signal/signal-blueprint", "item/blueprint")
local RESEARCH_ICON = sprite_or_fallback("virtual-signal/signal-science-pack", "utility/technology_white")
local HARVESTING_ICON = sprite_or_fallback("virtual-signal/signal-axe", "utility/hand")
local NEXT_SPLIT_COLOR = { r = 0.82, g = 0.82, b = 0.82 }
local NEXT_SPLIT_HOVER_COLOR = { r = 1, g = 1, b = 1 }

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
  hud.style.width = HUD_WIDTH

  local header = hud.add({
    type = "flow",
    name = HEADER_NAME,
    direction = "horizontal"
  })
  header.add({
    type = "label",
    name = PLAN_NAME
  })
  header[PLAN_NAME].style.horizontally_stretchable = true
  local next_plan_button = header.add({
    type = "sprite-button",
    name = NEXT_PLAN_BUTTON_NAME,
    sprite = "utility/right_arrow",
    tooltip = "Load the next [LP] blueprint book in your library."
  })
  next_plan_button.style.width = 16
  next_plan_button.style.height = 16

  hud.add({
    type = "label",
    name = PREVIOUS_NAME
  })
  hud.add({
    type = "label",
    name = CURRENT_NAME
  })
  tri_color_progress_bar.add(hud, CONSTRUCTION_PROGRESS_NAME, HUD_WIDTH, CONSTRUCTION_ICON)
  icon_quantity_list.add(hud, CONSTRUCTION_SHORTFALLS_NAME, HUD_WIDTH)
  tri_color_progress_bar.add(hud, RESEARCH_PROGRESS_NAME, HUD_WIDTH, RESEARCH_ICON)
  icon_quantity_list.add(hud, RESEARCH_SHORTFALLS_NAME, HUD_WIDTH)
  tri_color_progress_bar.add(hud, EXTRA_ITEM_PROGRESS_NAME, HUD_WIDTH, HARVESTING_ICON)
  icon_quantity_list.add(hud, EXTRA_ITEM_SHORTFALLS_NAME, HUD_WIDTH)
  hud.add({
    type = "button",
    name = ADVANCE_SPLIT_BUTTON_NAME,
    style = "transparent_button",
    tooltip = "Mark the current split complete."
  })
  hud[ADVANCE_SPLIT_BUTTON_NAME].style.font_color = NEXT_SPLIT_COLOR
  hud[ADVANCE_SPLIT_BUTTON_NAME].style.hovered_font_color = NEXT_SPLIT_HOVER_COLOR
  hud[ADVANCE_SPLIT_BUTTON_NAME].style.clicked_font_color = NEXT_SPLIT_HOVER_COLOR
  tri_color_progress_bar.add(hud, NEXT_SPLIT_CONSTRUCTION_PROGRESS_NAME, HUD_WIDTH, CONSTRUCTION_ICON)
  icon_quantity_list.add(hud, NEXT_SPLIT_CONSTRUCTION_SHORTFALLS_NAME, HUD_WIDTH)

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
  local construction = hud[CONSTRUCTION_PROGRESS_NAME]
  local research = hud[RESEARCH_PROGRESS_NAME]
  local extra_items = hud[EXTRA_ITEM_PROGRESS_NAME]
  local construction_shortfalls = hud[CONSTRUCTION_SHORTFALLS_NAME]
  local research_shortfalls = hud[RESEARCH_SHORTFALLS_NAME]
  local extra_item_shortfalls = hud[EXTRA_ITEM_SHORTFALLS_NAME]
  local advance_split_button = hud[ADVANCE_SPLIT_BUTTON_NAME]
  local next_split_construction = hud[NEXT_SPLIT_CONSTRUCTION_PROGRESS_NAME]
  local next_split_construction_shortfalls = hud[NEXT_SPLIT_CONSTRUCTION_SHORTFALLS_NAME]

  if not view then
    plan_name.caption = "No active speedrun"
    previous.visible = false
    current.visible = false
    construction.visible = false
    research.visible = false
    extra_items.visible = false
    construction_shortfalls.visible = false
    research_shortfalls.visible = false
    extra_item_shortfalls.visible = false
    advance_split_button.visible = false
    next_split_construction.visible = false
    next_split_construction_shortfalls.visible = false
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
  if view.construction_progress then
    tri_color_progress_bar.refresh(construction, view.construction_progress)
    icon_quantity_list.refresh(construction_shortfalls, view.construction_progress.unfinished_items)
  else
    construction.visible = false
    construction_shortfalls.visible = false
  end
  if view.research_progress then
    tri_color_progress_bar.refresh(research, view.research_progress)
    icon_quantity_list.refresh(research_shortfalls, view.research_progress.unfinished_items)
  else
    research.visible = false
    research_shortfalls.visible = false
  end
  if view.extra_item_progress then
    tri_color_progress_bar.refresh(extra_items, view.extra_item_progress)
    icon_quantity_list.refresh(extra_item_shortfalls, view.extra_item_progress.unfinished_items)
  else
    extra_items.visible = false
    extra_item_shortfalls.visible = false
  end
  advance_split_button.visible = view.next_split_label ~= nil
  advance_split_button.caption = view.next_split_label or ""
  if view.next_split_construction_progress then
    tri_color_progress_bar.refresh(next_split_construction, view.next_split_construction_progress)
    icon_quantity_list.refresh(
      next_split_construction_shortfalls,
      view.next_split_construction_progress.unfinished_items
    )
  else
    next_split_construction.visible = false
    next_split_construction_shortfalls.visible = false
  end
end

return M
