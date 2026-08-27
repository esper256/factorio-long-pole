-- Compact gameplay HUD for the active speedrun plan. It deliberately knows
-- only about presentation; runtime state and library traversal stay elsewhere.
local tri_color_progress_bar = require("hud.tri_color_progress_bar")
local icon_quantity_list = require("hud.icon_quantity_list")

local M = {}

local HUD_NAME = "long_pole_speedrun_hud"
local HEADER_NAME = "speedrun_header"
local PLAN_NAME = "active_speedrun_name"
local CLOCK_NAME = "game_clock"
local PREVIOUS_NAME = "previous_split"
local CURRENT_NAME = "current_split"
local NEXT_ROW_NAME = "next_split_row"
local NEXT_TITLE_NAME = "next_split_title"
local ADVANCE_SPLIT_BUTTON_NAME = "long_pole_advance_split"
local NEXT_PLAN_BUTTON_NAME = "long_pole_next_plan"
local CONSTRUCTION_PROGRESS_NAME = "construction_progress"
local RESEARCH_PROGRESS_NAME = "research_progress"
local CONSTRUCTION_SHORTFALLS_NAME = "construction_shortfalls"
local RESEARCH_SHORTFALLS_NAME = "research_shortfalls"
local NEXT_SPLIT_PRODUCTION_PROGRESS_NAME = "next_split_production_progress"
local NEXT_SPLIT_PRODUCTION_SHORTFALLS_NAME = "next_split_production_shortfalls"
local HUD_WIDTH = 192
local DIM_COLOR = { r = 0.62, g = 0.62, b = 0.62 }
local NEXT_COLOR = { r = 0.82, g = 0.82, b = 0.82 }

local function sprite_or_fallback(preferred, fallback)
  if helpers and helpers.is_valid_sprite_path(preferred) then
    return preferred
  end
  return fallback
end

local CONSTRUCTION_ICON = sprite_or_fallback("virtual-signal/signal-blueprint", "item/blueprint")
local PRODUCTION_ICON = sprite_or_fallback("item/assembling-machine-1", "item/iron-gear-wheel")
local RESEARCH_ICON = sprite_or_fallback("virtual-signal/signal-science-pack", "utility/technology_white")

local function display_plan_label(label)
  return (label or ""):gsub("%s*%[LP%]$", "")
end

local function game_time_caption(tick)
  local total_seconds = math.floor((tick or 0) / 60)
  local hours = math.floor(total_seconds / 3600)
  local minutes = math.floor(total_seconds % 3600 / 60)
  local seconds = total_seconds % 60
  if hours > 0 then
    return ("%d:%02d:%02d"):format(hours, minutes, seconds)
  end
  return ("%d:%02d"):format(minutes, seconds)
end

local function add_split_row(parent, name)
  local row = parent.add({
    type = "flow",
    name = name,
    direction = "horizontal"
  })
  row.style.horizontal_spacing = 6
  row.style.vertically_stretchable = false
  local title = row.add({
    type = "label",
    name = "title"
  })
  title.style.horizontally_stretchable = true
  row.add({
    type = "label",
    name = "time"
  })
  return row
end

local function build(player)
  local hud = player.gui.left.add({
    type = "frame",
    name = HUD_NAME,
    direction = "vertical"
  })
  hud.style.padding = 6
  hud.style.natural_width = HUD_WIDTH + 12

  local header = hud.add({
    type = "flow",
    name = HEADER_NAME,
    direction = "horizontal"
  })
  header.style.vertical_align = "center"
  header.style.horizontally_stretchable = true
  local plan_name = header.add({
    type = "label",
    name = PLAN_NAME
  })
  plan_name.style.horizontally_stretchable = true
  plan_name.style.font = "default-bold"
  header.add({
    type = "label",
    name = CLOCK_NAME
  })
  local next_plan_button = header.add({
    type = "sprite-button",
    name = NEXT_PLAN_BUTTON_NAME,
    style = "frame_action_button",
    sprite = "utility/right_arrow",
    tooltip = "Load the next [LP] blueprint book in your library."
  })
  next_plan_button.style.width = 20
  next_plan_button.style.height = 20
  next_plan_button.style.padding = 0

  local previous = add_split_row(hud, PREVIOUS_NAME)
  previous.title.style.font_color = DIM_COLOR
  previous.time.style.font_color = DIM_COLOR

  local current = add_split_row(hud, CURRENT_NAME)
  current.title.style.font = "default-bold"
  current.time.visible = false

  tri_color_progress_bar.add(hud, CONSTRUCTION_PROGRESS_NAME, HUD_WIDTH, CONSTRUCTION_ICON)
  icon_quantity_list.add(hud, CONSTRUCTION_SHORTFALLS_NAME, HUD_WIDTH)
  tri_color_progress_bar.add(hud, RESEARCH_PROGRESS_NAME, HUD_WIDTH, RESEARCH_ICON)
  icon_quantity_list.add(hud, RESEARCH_SHORTFALLS_NAME, HUD_WIDTH)

  local next_row = hud.add({
    type = "flow",
    name = NEXT_ROW_NAME,
    direction = "horizontal"
  })
  next_row.style.vertical_align = "center"
  next_row.style.horizontal_spacing = 4
  local next_title = next_row.add({
    type = "label",
    name = NEXT_TITLE_NAME
  })
  next_title.style.horizontally_stretchable = true
  next_title.style.font_color = NEXT_COLOR
  local advance_button = next_row.add({
    type = "sprite-button",
    name = ADVANCE_SPLIT_BUTTON_NAME,
    style = "frame_action_button",
    sprite = "utility/right_arrow",
    tooltip = "Advance to this split (Shift+Period)."
  })
  advance_button.style.width = 20
  advance_button.style.height = 20
  advance_button.style.padding = 0

  tri_color_progress_bar.add(hud, NEXT_SPLIT_PRODUCTION_PROGRESS_NAME, HUD_WIDTH, PRODUCTION_ICON)
  icon_quantity_list.add(hud, NEXT_SPLIT_PRODUCTION_SHORTFALLS_NAME, HUD_WIDTH)

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

local function hud_needs_rebuild(hud)
  return hud.type ~= "frame"
    or hud[HEADER_NAME] == nil
    or hud[HEADER_NAME][CLOCK_NAME] == nil
    or hud[NEXT_ROW_NAME] == nil
end

function M.refresh(player, view)
  if not (player and player.valid) then
    return
  end

  local existing = player.gui.left[HUD_NAME]
  if existing and hud_needs_rebuild(existing) then
    existing.destroy()
    existing = nil
  end
  local hud = existing or build(player)
  local header = hud[HEADER_NAME]
  local plan_name = header[PLAN_NAME]
  local clock = header[CLOCK_NAME]
  local previous = hud[PREVIOUS_NAME]
  local current = hud[CURRENT_NAME]
  local construction = hud[CONSTRUCTION_PROGRESS_NAME]
  local research = hud[RESEARCH_PROGRESS_NAME]
  local construction_shortfalls = hud[CONSTRUCTION_SHORTFALLS_NAME]
  local research_shortfalls = hud[RESEARCH_SHORTFALLS_NAME]
  local next_row = hud[NEXT_ROW_NAME]
  local next_title = next_row[NEXT_TITLE_NAME]
  local next_split_production = hud[NEXT_SPLIT_PRODUCTION_PROGRESS_NAME]
  local next_split_production_shortfalls = hud[NEXT_SPLIT_PRODUCTION_SHORTFALLS_NAME]

  if not view then
    plan_name.caption = "No active speedrun"
    clock.caption = ""
    previous.visible = false
    current.visible = false
    construction.visible = false
    research.visible = false
    construction_shortfalls.visible = false
    research_shortfalls.visible = false
    next_row.visible = false
    next_split_production.visible = false
    next_split_production_shortfalls.visible = false
    return
  end

  plan_name.caption = display_plan_label(view.plan_label)
  clock.caption = game_time_caption(view.game_tick)
  current.visible = true
  current.title.caption = view.current_split_label

  if view.previous_split_label then
    previous.visible = true
    previous.title.caption = view.previous_split_label
    previous.time.caption = game_time_caption(view.previous_split_finished_tick)
  else
    previous.visible = false
  end

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

  if view.next_split_label then
    next_row.visible = true
    next_title.caption = view.next_split_label
  else
    next_row.visible = false
  end
  if view.next_split_production_progress then
    tri_color_progress_bar.refresh(next_split_production, view.next_split_production_progress)
    icon_quantity_list.refresh(
      next_split_production_shortfalls,
      view.next_split_production_progress.unfinished_items
    )
  else
    next_split_production.visible = false
    next_split_production_shortfalls.visible = false
  end
end

return M
