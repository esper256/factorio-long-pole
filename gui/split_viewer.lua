local tracker = require("split_tracker")

local M = {}

M.root_name = "long_pole_split_viewer"
M.open_editor_button_name = "long_pole_open_plan_editor"
M.advance_split_button_name = "long_pole_advance_split"

local function destroy_children(element)
  for _, child in pairs(element.children) do
    child.destroy()
  end
end

local function format_missing_items(missing)
  if #missing == 0 then
    return "No remaining requirements"
  end

  local parts = {}
  local max_items = math.min(#missing, 3)
  for index = 1, max_items do
    local item = missing[index]
    parts[#parts + 1] = ("%s x%d"):format(item.name, item.count)
  end

  return table.concat(parts, ", ")
end

local function add_split_row(parent, status)
  if not status then
    return
  end

  local row = parent.add({
    type = "flow",
    direction = "horizontal"
  })
  row.style.horizontally_stretchable = true
  row.style.horizontal_spacing = 8

  local name_label = row.add({
    type = "label",
    caption = status.name
  })
  name_label.style.minimal_width = 150
  if status.is_current then
    name_label.style = "bold_label"
  end

  local delta_label = row.add({
    type = "label",
    caption = status.delta_caption
  })
  delta_label.style.minimal_width = 45
  delta_label.style.font_color = {0.75, 0.75, 0.75}

  local requirements_label = row.add({
    type = "label",
    caption = format_missing_items(status.missing)
  })
  requirements_label.style.maximal_width = 260
  requirements_label.style.horizontally_stretchable = true
  requirements_label.style.font_color = status.is_current and {1, 1, 1} or {0.85, 0.85, 0.85}

  if status.is_current then
    local button = row.add({
      type = "button",
      name = M.advance_split_button_name,
      caption = status.is_complete and "Complete" or "Advance"
    })
    button.style.left_margin = 4
    if status.is_complete then
      button.style.font_color = {0.3, 0.8, 0.3}
    end
  end
end

function M.refresh(player, state)
  local frame = player.gui.left[M.root_name]
  if not frame then
    frame = player.gui.left.add({
      type = "frame",
      name = M.root_name,
      direction = "vertical"
    })
    frame.style.horizontally_stretchable = true
  end

  destroy_children(frame)

  local header = frame.add({
    type = "flow",
    direction = "horizontal"
  })
  header.style.horizontally_stretchable = true

  local title = header.add({
    type = "label",
    caption = "Long Pole Splits"
  })
  title.style = "heading_2_label"

  local open_editor = header.add({
    type = "button",
    name = M.open_editor_button_name,
    caption = "Edit Plan"
  })
  open_editor.style.left_margin = 8

  local body = frame.add({
    type = "flow",
    direction = "vertical"
  })
  body.style.top_margin = 6

  local status = tracker.get_split_status(state)
  add_split_row(body, status.previous)
  add_split_row(body, status.current)
  for _, split_status in ipairs(status.upcoming) do
    add_split_row(body, split_status)
  end
end

function M.handle_click(player, state, element)
  if element.name == M.advance_split_button_name then
    tracker.advance_split(state)
    return true
  end

  return false
end

return M
