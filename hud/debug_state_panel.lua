-- Developer-only HUD panel for inspecting the current game-state ledger while
-- the real gameplay HUD is still under development.
local game_state = require("game_state.game_state")

local M = {}

local PANEL_NAME = "long_pole_debug_state_panel"
local MAX_ROWS = 8
local PANEL_WIDTH = 300
local HEADING_CAPTIONS = {"", "Produced", "Consumed", "Loose"}

local function panel_caption()
  return "Long Pole Debug"
end

local function product_icon_name(product_name)
  if prototypes.item[product_name] then
    return "item/" .. product_name
  end

  if prototypes.fluid[product_name] then
    return "fluid/" .. product_name
  end

  return "utility/questionmark"
end

local function produced_caption(product)
  local produced = game_state.total_products_produced(product)

  if product.destroyed > 0 then
    return ("%d - %d"):format(produced, product.destroyed)
  end
  return tostring(produced)
end

local function consumed_caption(product)
  if product.placed > 0 then
    return ("%d + %d"):format(product.consumed, product.placed)
  end
  return tostring(product.consumed)
end

local function build_rows(table_element, state)
  local rows_added = 0

  for _, surface_name in ipairs(game_state.sorted_surface_names(state)) do
    local surface = state.surfaces[surface_name]
    for _, product_name in ipairs(game_state.sorted_product_names(surface)) do
      local product = surface.products[product_name]

      table_element.add({
        type = "sprite",
        sprite = product_icon_name(product_name),
        tooltip = product_name
      })
      table_element.add({
        type = "label",
        caption = produced_caption(product)
      })
      table_element.add({type = "label", caption = consumed_caption(product)})
      table_element.add({
        type = "label",
        caption = tostring(game_state.loose_stock(product))
      })

      rows_added = rows_added + 1
      if rows_added >= MAX_ROWS then
        return
      end
    end
  end
end

local function build_panel(player, state)
  local frame = player.gui.left.add({
    type = "frame",
    name = PANEL_NAME,
    direction = "vertical",
    caption = panel_caption()
  })
  frame.style.minimal_width = PANEL_WIDTH
  frame.style.horizontally_stretchable = true

  local table_element = frame.add({
    type = "table",
    name = "rows",
    column_count = 4
  })
  table_element.style.horizontally_stretchable = true
  table_element.style.horizontal_spacing = 12
  table_element.style.vertical_spacing = 4

  for _, caption in ipairs(HEADING_CAPTIONS) do
    local heading = table_element.add({
      type = "label",
      caption = caption
    })
    heading.style.font = "default-bold"
  end

  build_rows(table_element, state)
end

function M.is_visible(player)
  return player.gui.left[PANEL_NAME] ~= nil
end

function M.hide(player)
  local existing = player.gui.left[PANEL_NAME]
  if existing then
    existing.destroy()
  end
end

function M.show(player, state)
  if not (player and player.valid) then
    return
  end

  if M.is_visible(player) then
    return
  end

  build_panel(player, state)
end

function M.refresh(player, state)
  if not (player and player.valid) or not M.is_visible(player) then
    return
  end

  local frame = player.gui.left[PANEL_NAME]
  local table_element = frame.rows
  table_element.clear()
  for _, caption in ipairs(HEADING_CAPTIONS) do
    local heading = table_element.add({
      type = "label",
      caption = caption
    })
    heading.style.font = "default-bold"
  end
  build_rows(table_element, state)
end

function M.toggle(player, state)
  if not (player and player.valid) then
    return
  end

  if M.is_visible(player) then
    M.hide(player)
    return
  end

  M.show(player, state)
end

return M
