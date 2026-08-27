local M = {}

M.CONTROL_COLUMN_WIDTH = 220
M.BLUEPRINT_PANEL_WIDTH = 320
M.EXTRA_ITEMS_PANEL_WIDTH = 280
M.TOTAL_PANEL_MIN_WIDTH = 420
M.RESEARCH_COLUMN_WIDTH = 220
M.TITLE_FIELD_MIN_WIDTH = 320
M.TITLE_FIELD_MAX_WIDTH = 520
M.HEADER_TO_FIELDS_GAP = 10
M.COLUMN_SPACING = 6
M.BUILD_GRID_COLUMNS = 12
M.BUILD_GRID_SLOT_SIZE = 40
M.EXTRA_ITEM_GRID_COLUMNS = 4
M.EXTRA_ITEM_SLOT_SIZE = 40
M.RESEARCH_GRID_COLUMNS = 4
M.RESEARCH_SLOT_SIZE = 40
M.BLUEPRINT_CHIP_HEIGHT = 50
M.PANEL_HEADER_HEIGHT = 32
M.GRID_VERTICAL_SPACING = 4
M.GRID_CHROME_HEIGHT = 18
M.PLANET_BUTTON_SIZE = 30
M.COMPACT_ICON_BUTTON_SIZE = 28
M.RESEARCH_ADD_BUTTON_WIDTH = 28
M.BUILD_COLUMN_WIDTH = M.BLUEPRINT_PANEL_WIDTH + M.COLUMN_SPACING + M.EXTRA_ITEMS_PANEL_WIDTH
M.MIN_SPLIT_ROW_WIDTH = M.CONTROL_COLUMN_WIDTH + M.HEADER_TO_FIELDS_GAP + M.BUILD_COLUMN_WIDTH + M.COLUMN_SPACING + M.RESEARCH_COLUMN_WIDTH + M.COLUMN_SPACING + M.TOTAL_PANEL_MIN_WIDTH

function M.count_grid_rows(entry_count, column_count)
  if entry_count <= 0 then
    return 1
  end

  return math.ceil(entry_count / column_count)
end

function M.compute_grid_height(entry_count, column_count, slot_size)
  local rows = M.count_grid_rows(entry_count, column_count)
  return rows * slot_size + ((rows - 1) * M.GRID_VERTICAL_SPACING) + M.GRID_CHROME_HEIGHT
end

function M.compute_window_dimensions(player)
  local width = math.floor((player.display_resolution.width / player.display_scale) * 0.94)
  local height = math.floor((player.display_resolution.height / player.display_scale) * 0.86)
  return math.max(1080, width), math.max(680, height)
end

function M.style_compact_button(button, width, height)
  button.style.width = width
  button.style.height = height or width
  button.style.left_padding = 0
  button.style.right_padding = 0
  button.style.top_padding = 0
  button.style.bottom_padding = 0
end

function M.add_header_gap(parent, width)
  local gap = parent.add({
    type = "empty-widget"
  })
  gap.style.width = width
  gap.style.height = 1
  return gap
end

function M.add_header_label(parent, caption, width, stretch)
  local label = parent.add({
    type = "label",
    caption = caption
  })
  label.style = "semibold_label"
  if stretch then
    label.style.horizontally_stretchable = true
    label.style.minimal_width = width
  else
    label.style.minimal_width = width
    label.style.maximal_width = width
  end
  return label
end

return M
