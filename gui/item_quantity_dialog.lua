local slot_grid = require("gui.slot_grid")

local M = {}

local DIALOG_WIDTH = 540
local DIALOG_HEIGHT = 680
local DEFAULT_MIN_COUNT = 1
local DEFAULT_SLIDER_MAX_COUNT = 1000
local ITEM_GRID_COLUMNS = 10
local ITEM_GRID_SLOT_SIZE = 40
local ITEM_GRID_HEIGHT = 520

M.root_name = "long_pole_item_quantity_dialog"
M.body_name = "long_pole_item_quantity_dialog_body"
M.search_field_name = "long_pole_item_quantity_dialog_search"
M.search_button_name = "long_pole_item_quantity_dialog_search_button"
M.item_option_button_name = "long_pole_item_quantity_dialog_item_option"
M.count_slider_name = "long_pole_item_quantity_dialog_slider"
M.count_field_name = "long_pole_item_quantity_dialog_count"
M.confirm_button_name = "long_pole_item_quantity_dialog_confirm"
M.close_button_name = "long_pole_item_quantity_dialog_close"

local function ensure_registry(state)
  state.item_quantity_dialogs = state.item_quantity_dialogs or {}
  return state.item_quantity_dialogs
end

local function get_dialog(state, player_index)
  return ensure_registry(state)[player_index]
end

local function clamp_count(value, minimum_count, maximum_count)
  local numeric = math.floor(tonumber(value) or minimum_count or DEFAULT_MIN_COUNT)
  local minimum = minimum_count or DEFAULT_MIN_COUNT
  local maximum = math.max(minimum, maximum_count or DEFAULT_SLIDER_MAX_COUNT)
  if numeric < minimum then
    return minimum
  end
  if numeric > maximum then
    return maximum
  end
  return numeric
end

local function parse_count(text)
  local numeric = tonumber(text)
  if not numeric then
    return nil
  end

  numeric = math.floor(numeric)
  if numeric < 1 then
    return nil
  end

  return numeric
end

local function get_item_prototypes()
  if prototypes and prototypes.item then
    return prototypes.item
  end

  if game and game.item_prototypes then
    return game.item_prototypes
  end

  return {}
end

local function sort_key(value)
  return value or ""
end

local function list_item_entries()
  local item_prototypes = get_item_prototypes()
  local entries = {}

  for item_name, prototype in pairs(item_prototypes) do
    if not prototype.hidden then
      entries[#entries + 1] = {
        name = item_name,
        tooltip = prototype.localised_name or item_name
      }
    end
  end

  table.sort(entries, function(a, b)
    local prototype_a = item_prototypes[a.name]
    local prototype_b = item_prototypes[b.name]

    local subgroup_a = prototype_a and prototype_a.subgroup or nil
    local subgroup_b = prototype_b and prototype_b.subgroup or nil
    local group_a = subgroup_a and subgroup_a.group or nil
    local group_b = subgroup_b and subgroup_b.group or nil

    local group_order_a = sort_key(group_a and group_a.order)
    local group_order_b = sort_key(group_b and group_b.order)
    if group_order_a ~= group_order_b then
      return group_order_a < group_order_b
    end

    local subgroup_order_a = sort_key(subgroup_a and subgroup_a.order)
    local subgroup_order_b = sort_key(subgroup_b and subgroup_b.order)
    if subgroup_order_a ~= subgroup_order_b then
      return subgroup_order_a < subgroup_order_b
    end

    local order_a = sort_key(prototype_a and prototype_a.order)
    local order_b = sort_key(prototype_b and prototype_b.order)
    if order_a ~= order_b then
      return order_a < order_b
    end

    return a.name < b.name
  end)

  return entries
end

local function root_for_player(player)
  return player.gui.screen[M.root_name]
end

local function find_body(player)
  local root = root_for_player(player)
  if not root then
    return nil
  end

  return root[M.body_name]
end

local function find_slider(player)
  local body = find_body(player)
  return body and body[M.count_slider_name] or nil
end

local function find_count_field(player)
  local body = find_body(player)
  return body and body[M.count_field_name] or nil
end

local function sync_controls(player, dialog)
  local slider = find_slider(player)
  if slider and slider.valid then
    local slider_minimum = slider.get_slider_minimum()
    local slider_maximum = slider.get_slider_maximum()
    if slider_minimum ~= dialog.minimum_count or slider_maximum ~= dialog.slider_maximum_count then
      slider.set_slider_minimum_maximum(dialog.minimum_count, dialog.slider_maximum_count)
    end

    local slider_value = clamp_count(dialog.count, dialog.minimum_count, dialog.slider_maximum_count)
    if slider.slider_value ~= slider_value then
      slider.slider_value = slider_value
    end
  end

  local count_field = find_count_field(player)
  if count_field and count_field.valid and count_field.text ~= dialog.count_text then
    count_field.text = dialog.count_text
  end
end

function M.close(player, state)
  ensure_registry(state)[player.index] = nil

  local root = root_for_player(player)
  if root then
    root.destroy()
  end
end

local function confirm_dialog(player, state, dialog)
  local parsed_count = parse_count(dialog.count_text)
  if not parsed_count then
    player.print("Enter a quantity of at least 1.")
    return {action = "handled"}
  end

  dialog.count = parsed_count
  dialog.count_text = tostring(parsed_count)

  local result = {
    action = "confirm",
    elem_value = dialog.elem_value,
    count = dialog.count,
    context = dialog.context
  }
  M.close(player, state)
  return result
end

function M.open(player, state, options)
  options = options or {}

  local minimum_count = math.max(DEFAULT_MIN_COUNT, options.minimum_count or DEFAULT_MIN_COUNT)
  local initial_count = parse_count(options.count) or minimum_count

  ensure_registry(state)[player.index] = {
    title = options.title or "Select Item",
    confirm_caption = options.confirm_caption or "Confirm",
    elem_type = options.elem_type or "item",
    elem_value = options.elem_value,
    item_entries = list_item_entries(),
    minimum_count = minimum_count,
    slider_maximum_count = math.max(minimum_count, options.slider_maximum_count or DEFAULT_SLIDER_MAX_COUNT),
    count = math.max(minimum_count, initial_count),
    count_text = tostring(math.max(minimum_count, initial_count)),
    context = options.context or {}
  }

  local existing_root = root_for_player(player)
  if existing_root then
    existing_root.destroy()
  end

  local dialog = get_dialog(state, player.index)
  local frame = player.gui.screen.add({
    type = "frame",
    name = M.root_name,
    direction = "vertical"
  })
  frame.auto_center = true
  frame.style.width = DIALOG_WIDTH
  frame.style.height = DIALOG_HEIGHT

  local titlebar = frame.add({
    type = "flow",
    direction = "horizontal"
  })
  titlebar.drag_target = frame
  titlebar.style.horizontally_stretchable = true

  local title = titlebar.add({
    type = "label",
    caption = dialog.title
  })
  title.style = "frame_title"
  title.ignored_by_interaction = true

  local search_field = titlebar.add({
    type = "textfield",
    name = M.search_field_name,
    text = ""
  })
  search_field.style.horizontally_stretchable = true
  search_field.style.left_margin = 12
  search_field.style.right_margin = 4
  search_field.enabled = false

  local search_button = titlebar.add({
    type = "sprite-button",
    name = M.search_button_name,
    sprite = "utility/search_icon",
    style = "frame_action_button"
  })
  search_button.enabled = false

  titlebar.add({
    type = "sprite-button",
    name = M.close_button_name,
    sprite = "utility/close",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "frame_action_button"
  })

  local body = frame.add({
    type = "flow",
    name = M.body_name,
    direction = "vertical"
  })
  body.style.horizontally_stretchable = true
  body.style.vertically_stretchable = true
  body.style.top_margin = 12
  body.style.left_margin = 12
  body.style.right_margin = 12
  body.style.bottom_margin = 12
  body.style.vertical_spacing = 12

  slot_grid.add(body, dialog.item_entries, {
    top_margin = 2,
    minimal_height = ITEM_GRID_HEIGHT,
    maximal_height = ITEM_GRID_HEIGHT,
    column_count = ITEM_GRID_COLUMNS,
    slot_size = ITEM_GRID_SLOT_SIZE,
    horizontal_spacing = 2,
    vertical_spacing = 2,
    vertical_scroll_policy = "auto",
    horizontal_scroll_policy = "never",
    vertically_stretchable = true,
    button_name = M.item_option_button_name,
    build_tags = function(entry)
      return {
        item_name = entry and entry.name or nil
      }
    end,
    button_toggled = function(entry)
      return entry and entry.name == dialog.elem_value
    end,
    button_auto_toggle = true
  })

  local controls_row = body.add({
    type = "flow",
    direction = "horizontal"
  })
  controls_row.style.horizontally_stretchable = true
  controls_row.style.horizontal_spacing = 8

  local slider = controls_row.add({
    type = "slider",
    name = M.count_slider_name,
    minimum_value = dialog.minimum_count,
    maximum_value = dialog.slider_maximum_count,
    value_step = 1,
    discrete_values = true,
    value = clamp_count(dialog.count, dialog.minimum_count, dialog.slider_maximum_count)
  })
  slider.style.horizontally_stretchable = true
  slider.style.minimal_width = 260

  local count_field = controls_row.add({
    type = "textfield",
    name = M.count_field_name,
    text = dialog.count_text,
    numeric = true,
    allow_negative = false,
    allow_decimal = false
  })
  count_field.style.width = 120
  count_field.tooltip = "Enter the exact quantity to store in this slot."
  count_field.lose_focus_on_confirm = true

  local confirm_button = controls_row.add({
    type = "sprite-button",
    name = M.confirm_button_name,
    sprite = "utility/check_mark_green",
    hovered_sprite = "utility/check_mark_dark_green",
    clicked_sprite = "utility/check_mark_dark_green",
    style = "tool_button_green"
  })
  confirm_button.style.width = 40
  confirm_button.style.height = 40
  confirm_button.tooltip = dialog.confirm_caption
end

function M.handle_click(player, state, element)
  if slot_grid.matches_action(element, M.item_option_button_name) then
    local dialog = get_dialog(state, player.index)
    if not dialog then
      return {action = "handled"}
    end

    dialog.elem_value = element.tags.item_name
    M.open(player, state, {
      title = dialog.title,
      confirm_caption = dialog.confirm_caption,
      elem_type = dialog.elem_type,
      elem_value = dialog.elem_value,
      minimum_count = dialog.minimum_count,
      slider_maximum_count = dialog.slider_maximum_count,
      count = dialog.count,
      context = dialog.context
    })
    return {action = "handled"}
  end

  if element.name ~= M.confirm_button_name
    and element.name ~= M.close_button_name then
    return nil
  end

  local dialog = get_dialog(state, player.index)
  if not dialog then
    return {action = "handled"}
  end

  if element.name == M.close_button_name then
    M.close(player, state)
    return {action = "cancel"}
  end

  return confirm_dialog(player, state, dialog)
end

function M.handle_elem_changed(_player, _state, _element)
  return false
end

function M.handle_text_changed(player, state, element)
  if element.name ~= M.count_field_name then
    return false
  end

  local dialog = get_dialog(state, player.index)
  if not dialog then
    return false
  end

  dialog.count_text = element.text
  local parsed_count = parse_count(element.text)
  if not parsed_count then
    return true
  end

  dialog.count = parsed_count
  dialog.count_text = tostring(parsed_count)
  sync_controls(player, dialog)
  return true
end

function M.handle_value_changed(player, state, element)
  if element.name ~= M.count_slider_name then
    return false
  end

  local dialog = get_dialog(state, player.index)
  if not dialog then
    return false
  end

  dialog.count = clamp_count(element.slider_value, dialog.minimum_count, dialog.slider_maximum_count)
  dialog.count_text = tostring(dialog.count)

  local count_field = find_count_field(player)
  if count_field and count_field.valid then
    count_field.text = dialog.count_text
  end

  return true
end

function M.handle_confirmed(player, state, element)
  if element.name ~= M.count_field_name then
    return nil
  end

  local dialog = get_dialog(state, player.index)
  if not dialog then
    return {action = "handled"}
  end

  return confirm_dialog(player, state, dialog)
end

M.parse_count = parse_count

return M
