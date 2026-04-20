local plan_storage = require("plan_storage")
local tracker = require("split_tracker")

local M = {}

local SPLIT_ROW_HEIGHT = 240
local CONTROL_COLUMN_WIDTH = 190
local SHELF_HEIGHT = 180
local ITEM_GRID_COLUMNS = 4

M.root_name = "long_pole_plan_editor"
M.close_button_name = "long_pole_close_plan_editor"
M.add_split_button_name = "long_pole_add_split"
M.save_plan_button_name = "long_pole_save_plan"
M.split_list_name = "long_pole_split_list"
M.move_split_up_name = "long_pole_move_split_up"
M.move_split_down_name = "long_pole_move_split_down"
M.add_blueprint_button_name = "long_pole_add_blueprint"
M.replace_blueprint_button_name = "long_pole_replace_blueprint"
M.remove_blueprint_button_name = "long_pole_remove_blueprint"
M.add_item_button_name = "long_pole_add_item"
M.item_picker_name = "long_pole_item_picker"
M.item_count_field_name = "long_pole_item_count"
M.remove_item_button_name = "long_pole_remove_item"
M.name_field_name = "long_pole_split_name"
M.research_field_name = "long_pole_split_research"
M.notes_field_name = "long_pole_split_notes"

local function destroy_children(element)
  for _, child in pairs(element.children) do
    child.destroy()
  end
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

  local width = math.floor((player.display_resolution.width / player.display_scale) * 0.94)
  local height = math.floor((player.display_resolution.height / player.display_scale) * 0.86)
  frame.style.width = math.max(1080, width)
  frame.style.height = math.max(680, height)

  return frame
end

local function format_technologies(technologies)
  local entries = {}
  for _, technology in ipairs(technologies) do
    entries[#entries + 1] = technology.name or ""
  end
  return table.concat(entries, "\n")
end

local function parse_name_list(text)
  local entries = {}
  for raw_entry in (text or ""):gmatch("[^\r\n,]+") do
    local trimmed = raw_entry:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed ~= "" then
      entries[#entries + 1] = {name = trimmed}
    end
  end
  return entries
end

local function summarize_blueprint_entities(stack)
  local entities = stack.get_blueprint_entities() or {}
  local summary_by_name = {}

  for _, entity in ipairs(entities) do
    local entity_name = entity.name
    if entity_name and entity_name ~= "" then
      summary_by_name[entity_name] = (summary_by_name[entity_name] or 0) + 1
    end
  end

  local summary = {}
  for entity_name, count in pairs(summary_by_name) do
    summary[#summary + 1] = {
      name = entity_name,
      count = count
    }
  end

  table.sort(summary, function(a, b)
    if a.count == b.count then
      return a.name < b.name
    end

    return a.count > b.count
  end)

  return summary
end

local function get_held_blueprint(player)
  local candidate_stacks = {
    player.cursor_stack,
    player.blueprint_to_setup
  }

  local stack = nil
  local source_book_label = nil
  local source_book_active_index = nil
  local saw_any_stack = false

  for _, candidate in ipairs(candidate_stacks) do
    if candidate and candidate.valid_for_read then
      saw_any_stack = true

      if candidate.is_blueprint_book then
        local inventory = candidate.get_inventory(defines.inventory.item_main)
        local active_index = candidate.active_index
        if inventory and active_index and inventory[active_index] and inventory[active_index].valid_for_read then
          stack = inventory[active_index]
          source_book_label = candidate.label
          source_book_active_index = active_index
          break
        end
      elseif candidate.is_blueprint then
        stack = candidate
        break
      end
    end
  end

  if not stack then
    if saw_any_stack then
      return nil, "Hold a configured blueprint or blueprint book in the cursor first."
    end
    return nil, "Hold a configured blueprint or blueprint book in the cursor first."
  end

  if stack.get_blueprint_entity_count() < 1 then
    return nil, "The held blueprint is empty."
  end

  local blueprint_name = stack.label
  if not blueprint_name or blueprint_name == "" then
    blueprint_name = "Unnamed Blueprint"
  end

  return {
    name = blueprint_name,
    export_string = stack.export_stack(),
    entity_count = stack.get_blueprint_entity_count(),
    entity_summary = summarize_blueprint_entities(stack),
    source_book_label = source_book_label,
    source_book_active_index = source_book_active_index
  }, nil
end

local function add_section_title(parent, caption)
  local title = parent.add({
    type = "label",
    caption = caption
  })
  title.style = "semibold_label"
  return title
end

local function add_blueprint_shelf(parent, split)
  local shelf = parent.add({
    type = "frame",
    direction = "vertical"
  })
  shelf.style.width = 300
  shelf.style.height = SHELF_HEIGHT

  local header = shelf.add({
    type = "flow",
    direction = "horizontal"
  })
  header.style.horizontally_stretchable = true

  add_section_title(header, "Blueprints")

  local spacer = header.add({type = "empty-widget"})
  spacer.style.horizontally_stretchable = true

  local add_button = header.add({
    type = "button",
    name = M.add_blueprint_button_name,
    caption = "Use Held",
    tags = {split_id = split.id}
  })
  add_button.tooltip = "Capture the configured blueprint currently held in the cursor."

  local list = shelf.add({
    type = "scroll-pane",
    vertical_scroll_policy = "auto"
  })
  list.style.horizontally_stretchable = true
  list.style.top_margin = 6
  list.style.minimal_height = SHELF_HEIGHT - 40
  list.style.maximal_height = SHELF_HEIGHT - 40

  if #split.blueprints == 0 then
    local empty = list.add({
      type = "label",
      caption = "No linked blueprints yet. Hold a blueprint in the cursor and click Use Held."
    })
    empty.style.single_line = false
    empty.style.font_color = {0.8, 0.8, 0.8}
  end

  for blueprint_index, blueprint in ipairs(split.blueprints) do
    local row = list.add({
      type = "frame",
      direction = "horizontal"
    })
    row.style.horizontally_stretchable = true
    row.style.top_margin = 4

    local icon = row.add({
      type = "sprite-button",
      name = M.replace_blueprint_button_name,
      sprite = "item/blueprint",
      tags = {split_id = split.id, blueprint_index = blueprint_index}
    })
    icon.tooltip = "Click while holding a blueprint to replace this linked blueprint."

    local text = row.add({
      type = "flow",
      direction = "vertical"
    })
    text.style.horizontally_stretchable = true
    text.style.left_margin = 6

    local name = text.add({
      type = "label",
      caption = blueprint.name or "Unnamed Blueprint"
    })
    name.style.single_line = false

    local source_bits = {}
    if blueprint.source_book_label and blueprint.source_book_label ~= "" then
      source_bits[#source_bits + 1] = ("Book: %s"):format(blueprint.source_book_label)
    end
    if blueprint.entity_count then
      source_bits[#source_bits + 1] = ("%d entities"):format(blueprint.entity_count)
    end

    if #source_bits > 0 then
      local meta = text.add({
        type = "label",
        caption = table.concat(source_bits, "  |  ")
      })
      meta.style.font_color = {0.75, 0.75, 0.75}
    end

    local summary_pane = text.add({
      type = "scroll-pane",
      vertical_scroll_policy = "auto"
    })
    summary_pane.style.horizontally_stretchable = true
    summary_pane.style.top_margin = 4
    summary_pane.style.minimal_height = 74
    summary_pane.style.maximal_height = 74

    if blueprint.entity_summary and #blueprint.entity_summary > 0 then
      for _, entry in ipairs(blueprint.entity_summary) do
        local summary_row = summary_pane.add({
          type = "label",
          caption = ("%dx %s"):format(entry.count, entry.name)
        })
        summary_row.style.single_line = false
      end
    else
      local empty_summary = summary_pane.add({
        type = "label",
        caption = "No blueprint entities found."
      })
      empty_summary.style.single_line = false
      empty_summary.style.font_color = {0.75, 0.75, 0.75}
    end

    local remove_button = row.add({
      type = "button",
      name = M.remove_blueprint_button_name,
      caption = "X",
      tags = {split_id = split.id, blueprint_index = blueprint_index}
    })
    remove_button.tooltip = "Remove this linked blueprint from the split."
  end
end

local function add_item_shelf(parent, split)
  local shelf = parent.add({
    type = "frame",
    direction = "vertical"
  })
  shelf.style.width = 330
  shelf.style.height = SHELF_HEIGHT

  local header = shelf.add({
    type = "flow",
    direction = "horizontal"
  })
  header.style.horizontally_stretchable = true

  add_section_title(header, "Items")

  local spacer = header.add({type = "empty-widget"})
  spacer.style.horizontally_stretchable = true

  local add_button = header.add({
    type = "sprite-button",
    name = M.add_item_button_name,
    sprite = "utility/add",
    tags = {split_id = split.id}
  })
  add_button.style = "slot_button"
  add_button.style.width = 36
  add_button.style.height = 36
  add_button.tooltip = "Add an extra item requirement."

  local body = shelf.add({
    type = "scroll-pane",
    vertical_scroll_policy = "auto"
  })
  body.style.horizontally_stretchable = true
  body.style.top_margin = 6
  body.style.minimal_height = SHELF_HEIGHT - 40
  body.style.maximal_height = SHELF_HEIGHT - 40

  if #split.items == 0 then
    local empty = body.add({
      type = "label",
      caption = "No extra item requirements yet."
    })
    empty.style.single_line = false
    empty.style.font_color = {0.8, 0.8, 0.8}
    return
  end

  local grid = body.add({
    type = "table",
    column_count = ITEM_GRID_COLUMNS
  })
  grid.style.horizontal_spacing = 8
  grid.style.vertical_spacing = 8

  for item_index, item in ipairs(split.items) do
    local cell = grid.add({
      type = "frame",
      direction = "vertical"
    })
    cell.style.width = 68
    cell.style.height = 84

    local picker = cell.add({
      type = "choose-elem-button",
      name = M.item_picker_name,
      elem_type = "item",
      tags = {split_id = split.id, item_index = item_index}
    })
    picker.style = "slot_button"
    if item.name and item.name ~= "" then
      picker.elem_value = item.name
    end

    local controls = cell.add({
      type = "flow",
      direction = "horizontal"
    })
    controls.style.top_margin = 4
    controls.style.horizontal_spacing = 2

    local count_field = controls.add({
      type = "textfield",
      name = M.item_count_field_name,
      text = tostring(item.count or 1),
      tags = {split_id = split.id, item_index = item_index}
    })
    count_field.style.width = 34
    count_field.tooltip = "Required quantity for this split."

    local remove_button = controls.add({
      type = "sprite-button",
      name = M.remove_item_button_name,
      sprite = "utility/trash",
      tags = {split_id = split.id, item_index = item_index}
    })
    remove_button.style = "tool_button"
    remove_button.style.width = 24
    remove_button.style.height = 24
    remove_button.tooltip = "Remove this item requirement."
  end
end

local function add_text_column(parent, title_text, field_name, text_value, tooltip, split_id)
  local column = parent.add({
    type = "frame",
    direction = "vertical"
  })
  column.style.horizontally_stretchable = false
  column.style.width = 220
  column.style.height = SHELF_HEIGHT

  add_section_title(column, title_text)

  local editor = column.add({
    type = "text-box",
    name = field_name,
    text = text_value,
    tags = {split_id = split_id}
  })
  editor.style.horizontally_stretchable = true
  editor.style.minimal_height = SHELF_HEIGHT - 40
  editor.style.maximal_height = SHELF_HEIGHT - 40
  editor.tooltip = tooltip
end

local function add_split_row(parent, split_index, split, total_splits)
  local row = parent.add({
    type = "frame",
    direction = "horizontal",
    tags = {split_id = split.id}
  })
  row.style.horizontally_stretchable = true
  row.style.top_margin = 8
  row.style.minimal_height = SPLIT_ROW_HEIGHT
  row.style.maximal_height = SPLIT_ROW_HEIGHT

  local controls = row.add({
    type = "flow",
    direction = "vertical",
    name = "controls"
  })
  controls.style.minimal_width = CONTROL_COLUMN_WIDTH
  controls.style.maximal_width = CONTROL_COLUMN_WIDTH

  local name_row = controls.add({
    type = "flow",
    direction = "horizontal"
  })
  name_row.style.horizontally_stretchable = true
  name_row.style.horizontal_spacing = 6

  local row_label = name_row.add({
    type = "label",
    caption = "#" .. split_index
  })
  row_label.style = "grey_label"
  row_label.style.minimal_width = 18

  local name_field = name_row.add({
    type = "textfield",
    name = M.name_field_name,
    text = split.name,
    tags = {split_id = split.id}
  })
  name_field.style.horizontally_stretchable = true
  name_field.style.minimal_width = CONTROL_COLUMN_WIDTH - 32
  name_field.style.maximal_width = CONTROL_COLUMN_WIDTH - 32

  local move_buttons = controls.add({
    type = "flow",
    direction = "horizontal"
  })
  move_buttons.style.top_margin = 6
  move_buttons.style.horizontal_spacing = 6

  local up_button = move_buttons.add({
    type = "button",
    name = M.move_split_up_name,
    caption = "▲",
    tags = {split_id = split.id}
  })
  up_button.style.width = 36
  up_button.enabled = split_index > 1

  local down_button = move_buttons.add({
    type = "button",
    name = M.move_split_down_name,
    caption = "▼",
    tags = {split_id = split.id}
  })
  down_button.style.width = 36
  down_button.enabled = split_index < total_splits

  local controls_spacer = controls.add({
    type = "empty-widget"
  })
  controls_spacer.style.vertically_stretchable = true

  local fields = row.add({
    type = "flow",
    direction = "horizontal"
  })
  fields.style.horizontally_stretchable = true
  fields.style.horizontal_spacing = 8

  add_blueprint_shelf(fields, split)
  add_item_shelf(fields, split)

  add_text_column(
    fields,
    "Research",
    M.research_field_name,
    format_technologies(split.technologies),
    "One technology name per line.",
    split.id
  )
  add_text_column(
    fields,
    "Notes",
    M.notes_field_name,
    split.notes,
    "Planning notes, staged blueprint rules, and reminders.",
    split.id
  )
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
    type = "frame",
    direction = "vertical"
  })
  content.style.horizontally_stretchable = true
  content.style.vertically_stretchable = true
  content.style.top_margin = 8

  local toolbar = content.add({
    type = "flow",
    direction = "horizontal"
  })
  toolbar.style.horizontally_stretchable = true

  local toolbar_title = toolbar.add({
    type = "label",
    caption = state.plan_name or "Untitled Plan"
  })
  toolbar_title.style = "semibold_label"

  local toolbar_spacer = toolbar.add({
    type = "empty-widget"
  })
  toolbar_spacer.style.horizontally_stretchable = true

  local add_split_button = toolbar.add({
    type = "button",
    name = M.add_split_button_name,
    caption = "Add Split"
  })
  add_split_button.style.left_margin = 8

  local save_plan_button = toolbar.add({
    type = "button",
    name = M.save_plan_button_name,
    caption = "Save to New Book"
  })
  save_plan_button.style.left_margin = 8

  local split_list = content.add({
    type = "scroll-pane",
    name = M.split_list_name,
    vertical_scroll_policy = "auto"
  })
  split_list.style.vertically_stretchable = true
  split_list.style.horizontally_stretchable = true
  split_list.style.top_margin = 6

  if #state.splits == 0 then
    local empty_state = split_list.add({
      type = "label",
      caption = "No splits yet. Click Add Split to start building this run."
    })
    empty_state.style.single_line = false
    empty_state.style.font_color = {0.8, 0.8, 0.8}
    empty_state.style.top_margin = 12
  end

  for index, split in ipairs(state.splits) do
    add_split_row(split_list, index, split, #state.splits)
  end
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
    tracker.add_split(state)
    return true
  end

  if element.name == M.save_plan_button_name then
    local ok, error_message = plan_storage.export_plan_to_cursor(player, state)
    if not ok then
      player.print(error_message)
      return false
    end

    player.print("Saved active Long Pole plan to a new blueprint book in the cursor.")
    return "refresh-split-viewer"
  end

  if element.name == M.add_blueprint_button_name or element.name == M.replace_blueprint_button_name then
    local blueprint, error_message = get_held_blueprint(player)
    if not blueprint then
      player.print(error_message)
      return false
    end

    if element.name == M.add_blueprint_button_name then
      return tracker.add_split_blueprint_by_id(state, element.tags.split_id, blueprint)
    end

    return tracker.replace_split_blueprint_by_id(
      state,
      element.tags.split_id,
      element.tags.blueprint_index,
      blueprint
    )
  end

  if element.name == M.remove_blueprint_button_name then
    return tracker.remove_split_blueprint_by_id(state, element.tags.split_id, element.tags.blueprint_index)
  end

  if element.name == M.add_item_button_name then
    return tracker.add_split_item_by_id(state, element.tags.split_id, {count = 1})
  end

  if element.name == M.remove_item_button_name then
    return tracker.remove_split_item_by_id(state, element.tags.split_id, element.tags.item_index)
  end

  if element.name == M.move_split_up_name then
    local split_index = tracker.find_split_index_by_id(state, element.tags.split_id)
    if not split_index then
      return false
    end
    return tracker.move_split(state, split_index, split_index - 1)
  end

  if element.name == M.move_split_down_name then
    local split_index = tracker.find_split_index_by_id(state, element.tags.split_id)
    if not split_index then
      return false
    end
    return tracker.move_split(state, split_index, split_index + 1)
  end

  return false
end

function M.handle_text_changed(_player, state, element)
  local split_id = element.tags.split_id
  if not split_id then
    return false
  end

  if element.name == M.name_field_name then
    return tracker.rename_split_by_id(state, split_id, element.text)
  end

  if element.name == M.item_count_field_name then
    return tracker.set_split_item_count_by_id(state, split_id, element.tags.item_index, element.text)
  end

  if element.name == M.research_field_name then
    return tracker.set_split_technologies_by_id(state, split_id, parse_name_list(element.text))
  end

  if element.name == M.notes_field_name then
    return tracker.set_split_notes_by_id(state, split_id, element.text)
  end

  return false
end

function M.handle_elem_changed(_player, state, element)
  local split_id = element.tags.split_id
  if not split_id then
    return false
  end

  if element.name == M.item_picker_name then
    return tracker.set_split_item_name_by_id(state, split_id, element.tags.item_index, element.elem_value)
  end

  return false
end

return M
