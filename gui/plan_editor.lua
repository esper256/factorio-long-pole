local tracker = require("split_tracker")

local M = {}

M.root_name = "long_pole_plan_editor"
M.close_button_name = "long_pole_close_plan_editor"
M.add_split_button_name = "long_pole_add_split"
M.split_name_field_name = "long_pole_split_name"
M.select_split_prefix = "long_pole_select_split_"

local function destroy_children(element)
  for _, child in pairs(element.children) do
    child.destroy()
  end
end

local function selected_split(state, player)
  local index = tracker.get_selected_split_index(state, player.index)
  return index, tracker.get_split(state, index)
end

local function ensure_window(player)
  local frame = player.gui.screen[M.root_name]
  if frame then
    return frame
  end

  frame = player.gui.screen.add({
    type = "frame",
    name = M.root_name,
    direction = "vertical"
  })
  frame.auto_center = true

  local width = math.floor((player.display_resolution.width / player.display_scale) * 0.88)
  local height = math.floor((player.display_resolution.height / player.display_scale) * 0.82)
  frame.style.width = math.max(900, width)
  frame.style.height = math.max(620, height)

  return frame
end

local function add_summary_row(parent, caption, value)
  local row = parent.add({
    type = "flow",
    direction = "horizontal"
  })
  row.style.horizontal_spacing = 8

  local label = row.add({
    type = "label",
    caption = caption
  })
  label.style = "semibold_label"
  label.style.minimal_width = 110

  row.add({
    type = "label",
    caption = value
  })
end

local function add_section(parent, title_text, empty_text, entries)
  local frame = parent.add({
    type = "frame",
    direction = "vertical"
  })
  frame.style.horizontally_stretchable = true
  frame.style.vertically_stretchable = true

  local title = frame.add({
    type = "label",
    caption = title_text
  })
  title.style = "semibold_label"

  if #entries == 0 then
    local empty = frame.add({
      type = "label",
      caption = empty_text
    })
    empty.style.font_color = {0.65, 0.65, 0.65}
    return
  end

  local list = frame.add({
    type = "flow",
    direction = "vertical"
  })
  list.style.top_margin = 4

  for _, entry in ipairs(entries) do
    list.add({
      type = "label",
      caption = entry
    })
  end
end

function M.open(player, state)
  local frame = ensure_window(player)
  M.refresh(player, state)
  player.opened = frame
end

function M.close(player)
  local frame = player.gui.screen[M.root_name]
  if frame then
    frame.destroy()
  end
end

function M.refresh(player, state)
  local frame = player.gui.screen[M.root_name]
  if not frame then
    return
  end

  destroy_children(frame)

  local titlebar = frame.add({
    type = "flow",
    direction = "horizontal"
  })
  titlebar.drag_target = frame
  titlebar.style.horizontally_stretchable = true

  local title = titlebar.add({
    type = "label",
    caption = "Speedrun Plan Editor"
  })
  title.style = "frame_title"
  title.ignored_by_interaction = true

  local spacer = titlebar.add({
    type = "empty-widget"
  })
  spacer.style.horizontally_stretchable = true
  spacer.style.height = 24
  spacer.ignored_by_interaction = true

  titlebar.add({
    type = "sprite-button",
    name = M.close_button_name,
    sprite = "utility/close",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "frame_action_button"
  })

  local content = frame.add({
    type = "flow",
    direction = "horizontal"
  })
  content.style.horizontally_stretchable = true
  content.style.vertically_stretchable = true
  content.style.top_margin = 8
  content.style.horizontal_spacing = 12

  local sidebar = content.add({
    type = "frame",
    direction = "vertical"
  })
  sidebar.style.width = 280
  sidebar.style.vertically_stretchable = true

  local sidebar_header = sidebar.add({
    type = "flow",
    direction = "horizontal"
  })
  sidebar_header.style.horizontally_stretchable = true

  local sidebar_title = sidebar_header.add({
    type = "label",
    caption = "Splits"
  })
  sidebar_title.style = "semibold_label"

  local add_split_button = sidebar_header.add({
    type = "button",
    name = M.add_split_button_name,
    caption = "Add Split"
  })
  add_split_button.style.left_margin = 8

  local split_list = sidebar.add({
    type = "scroll-pane",
    vertical_scroll_policy = "auto"
  })
  split_list.style.vertically_stretchable = true
  split_list.style.horizontally_stretchable = true
  split_list.style.top_margin = 6

  local selected_index = tracker.get_selected_split_index(state, player.index)
  for index, split in ipairs(state.splits) do
    local button = split_list.add({
      type = "button",
      name = M.select_split_prefix .. index,
      caption = split.name
    })
    button.style.horizontally_stretchable = true
    button.style.bottom_margin = 4
    if index == selected_index then
      button.style.font_color = {0.3, 0.8, 0.3}
    end
  end

  local details = content.add({
    type = "frame",
    direction = "vertical"
  })
  details.style.horizontally_stretchable = true
  details.style.vertically_stretchable = true

  local _, split = selected_split(state, player)
  if not split then
    details.add({
      type = "label",
      caption = "No split selected."
    })
    return
  end

  local form = details.add({
    type = "flow",
    direction = "vertical"
  })
  form.style.horizontally_stretchable = true
  form.style.vertically_stretchable = true

  local name_label = form.add({
    type = "label",
    caption = "Split Name"
  })
  name_label.style = "semibold_label"

  local name_field = form.add({
    type = "textfield",
    name = M.split_name_field_name,
    text = split.name
  })
  name_field.style.horizontally_stretchable = true

  local summary = form.add({
    type = "frame",
    direction = "vertical"
  })
  summary.style.horizontally_stretchable = true
  summary.style.top_margin = 8

  local summary_title = summary.add({
    type = "label",
    caption = "Planning Summary"
  })
  summary_title.style = "semibold_label"

  add_summary_row(summary, "Blueprints", tostring(#split.blueprints))
  add_summary_row(summary, "Items", tostring(#split.items))
  add_summary_row(summary, "Research", tostring(#split.technologies))

  local sections = form.add({
    type = "table",
    column_count = 2
  })
  sections.style.horizontally_stretchable = true
  sections.style.vertically_stretchable = true
  sections.style.top_margin = 8

  local item_entries = {}
  for _, item in ipairs(split.items) do
    item_entries[#item_entries + 1] = ("%s x%d"):format(item.name, item.count or 0)
  end

  local blueprint_entries = {}
  for _, blueprint in ipairs(split.blueprints) do
    blueprint_entries[#blueprint_entries + 1] = blueprint.name or "Unnamed blueprint"
  end

  local technology_entries = {}
  for _, technology in ipairs(split.technologies) do
    technology_entries[#technology_entries + 1] = technology.name or "Unnamed technology"
  end

  add_section(sections, "Blueprints", "No blueprints added yet.", blueprint_entries)
  add_section(sections, "Items", "No extra item requirements yet.", item_entries)
  add_section(sections, "Research", "No technologies attached yet.", technology_entries)
  add_section(
    sections,
    "Notes",
    "Use this space for build heuristics, staged blueprint rules, or reminders.",
    split.notes ~= "" and {split.notes} or {}
  )
end

function M.handle_click(player, state, element)
  if element.name == M.close_button_name then
    M.close(player)
    return false
  end

  if element.name == "long_pole_open_plan_editor" then
    M.open(player, state)
    return true
  end

  if element.name == M.add_split_button_name then
    local split_index = tracker.add_split(state)
    tracker.set_selected_split_index(state, player.index, split_index)
    return true
  end

  local selected_index = tonumber(element.name:match("^" .. M.select_split_prefix .. "(%d+)$"))
  if selected_index then
    tracker.set_selected_split_index(state, player.index, selected_index)
    return true
  end

  return false
end

function M.handle_text_changed(player, state, element)
  if element.name ~= M.split_name_field_name then
    return false
  end

  local split_index = tracker.get_selected_split_index(state, player.index)
  return tracker.rename_split(state, split_index, element.text)
end

return M
