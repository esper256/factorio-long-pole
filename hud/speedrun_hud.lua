-- Compact gameplay HUD for the active speedrun plan. It deliberately knows
-- only about presentation; runtime state and library traversal stay elsewhere.
--
-- This is a tight left-side flow, not a framed panel. Frame padding, 20px
-- icons, and split-row chrome hide map. Density matches the original overlay:
-- 192px wide, 8px icons, no extra vertical gaps.
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
local CONSTRUCTION_SHORTFALLS_NAME = "construction_shortfalls"
local RESEARCH_SHORTFALLS_NAME = "research_shortfalls"
local NEXT_SPLIT_PRODUCTION_PROGRESS_NAME = "next_split_production_progress"
local NEXT_SPLIT_PRODUCTION_SHORTFALLS_NAME = "next_split_production_shortfalls"
local HUD_WIDTH = 192
local NEXT_SPLIT_COLOR = { r = 0.82, g = 0.82, b = 0.82 }
local NEXT_SPLIT_HOVER_COLOR = { r = 1, g = 1, b = 1 }

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

local function apply_tight_flow_style(element)
  element.style.padding = 0
  element.style.margin = 0
  element.style.vertical_spacing = 0
  element.style.horizontal_spacing = 0
end

local function build(player)
  local hud = player.gui.left.add({
    type = "flow",
    name = HUD_NAME,
    direction = "vertical"
  })
  hud.style.width = HUD_WIDTH
  apply_tight_flow_style(hud)

  local header = hud.add({
    type = "flow",
    name = HEADER_NAME,
    direction = "horizontal"
  })
  apply_tight_flow_style(header)
  header.style.vertical_align = "center"
  local plan_name = header.add({
    type = "label",
    name = PLAN_NAME
  })
  plan_name.style.horizontally_stretchable = true
  plan_name.style.padding = 0
  local next_plan_button = header.add({
    type = "sprite-button",
    name = NEXT_PLAN_BUTTON_NAME,
    sprite = "utility/right_arrow",
    tooltip = "Load the next [LP] blueprint book in your library."
  })
  next_plan_button.style.width = 16
  next_plan_button.style.height = 16
  next_plan_button.style.padding = 0

  local previous = hud.add({
    type = "label",
    name = PREVIOUS_NAME
  })
  previous.style.padding = 0
  local current = hud.add({
    type = "label",
    name = CURRENT_NAME
  })
  current.style.padding = 0
  tri_color_progress_bar.add(hud, CONSTRUCTION_PROGRESS_NAME, HUD_WIDTH, CONSTRUCTION_ICON)
  icon_quantity_list.add(hud, CONSTRUCTION_SHORTFALLS_NAME, HUD_WIDTH)
  tri_color_progress_bar.add(hud, RESEARCH_PROGRESS_NAME, HUD_WIDTH, RESEARCH_ICON)
  icon_quantity_list.add(hud, RESEARCH_SHORTFALLS_NAME, HUD_WIDTH)
  hud.add({
    type = "button",
    name = ADVANCE_SPLIT_BUTTON_NAME,
    style = "transparent_button",
    tooltip = "Advance to this split (Shift+Period)."
  })
  local advance_split_button = hud[ADVANCE_SPLIT_BUTTON_NAME]
  advance_split_button.style.font_color = NEXT_SPLIT_COLOR
  advance_split_button.style.hovered_font_color = NEXT_SPLIT_HOVER_COLOR
  advance_split_button.style.clicked_font_color = NEXT_SPLIT_HOVER_COLOR
  advance_split_button.style.padding = 0
  advance_split_button.style.margin = 0
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

-- Drop leftover framed / split-row HUDs from earlier revisions so a loaded
-- save does not keep the spacious overlay.
local function hud_needs_rebuild(hud)
  return hud.type ~= "flow"
    or hud[HEADER_NAME] == nil
    or hud[PREVIOUS_NAME] == nil
    or hud[PREVIOUS_NAME].type ~= "label"
    or hud[CURRENT_NAME] == nil
    or hud[CURRENT_NAME].type ~= "label"
    or hud[ADVANCE_SPLIT_BUTTON_NAME] == nil
    or hud[HEADER_NAME]["game_clock"] ~= nil
    or hud["next_split_row"] ~= nil
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
  local previous = hud[PREVIOUS_NAME]
  local current = hud[CURRENT_NAME]
  local construction = hud[CONSTRUCTION_PROGRESS_NAME]
  local research = hud[RESEARCH_PROGRESS_NAME]
  local construction_shortfalls = hud[CONSTRUCTION_SHORTFALLS_NAME]
  local research_shortfalls = hud[RESEARCH_SHORTFALLS_NAME]
  local advance_split_button = hud[ADVANCE_SPLIT_BUTTON_NAME]
  local next_split_production = hud[NEXT_SPLIT_PRODUCTION_PROGRESS_NAME]
  local next_split_production_shortfalls = hud[NEXT_SPLIT_PRODUCTION_SHORTFALLS_NAME]

  if not view then
    plan_name.caption = "No active speedrun"
    previous.visible = false
    current.visible = false
    construction.visible = false
    research.visible = false
    construction_shortfalls.visible = false
    research_shortfalls.visible = false
    advance_split_button.visible = false
    next_split_production.visible = false
    next_split_production_shortfalls.visible = false
    return
  end

  plan_name.caption = display_plan_label(view.plan_label)
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
  advance_split_button.visible = view.next_split_label ~= nil
  advance_split_button.caption = view.next_split_label or ""
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
