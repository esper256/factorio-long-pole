local blueprint_entity_summary = require("util.blueprint_entity_summary")
local blueprint_fingerprint = require("util.blueprint_fingerprint")
local blueprint_library = require("util.blueprint_library")
local build_requirements = require("build_requirements")
local item_quantity_dialog = require("gui.item_quantity_dialog")
local plan_storage = require("plan_storage")
local slot_grid = require("gui.slot_grid")
local tracker = require("split_tracker")
local cursor_blueprint_source = require("util.cursor_blueprint_source")

local M = {}

local CONTROL_COLUMN_WIDTH = 220
local BLUEPRINT_PANEL_WIDTH = 320
local EXTRA_ITEMS_PANEL_WIDTH = 280
local TOTAL_PANEL_MIN_WIDTH = 420
local RESEARCH_COLUMN_WIDTH = 220
local TITLE_FIELD_MIN_WIDTH = 320
local TITLE_FIELD_MAX_WIDTH = 520
local HEADER_TO_FIELDS_GAP = 10
local COLUMN_SPACING = 6
local BUILD_GRID_COLUMNS = 12
local BUILD_GRID_SLOT_SIZE = 40
local EXTRA_ITEM_GRID_COLUMNS = 4
local EXTRA_ITEM_SLOT_SIZE = 40
local RESEARCH_GRID_COLUMNS = 4
local RESEARCH_SLOT_SIZE = 40
local BLUEPRINT_CHIP_HEIGHT = 50
local PANEL_HEADER_HEIGHT = 32
local GRID_VERTICAL_SPACING = 4
local GRID_CHROME_HEIGHT = 18
local PLANET_BUTTON_SIZE = 30
local COMPACT_ICON_BUTTON_SIZE = 28
local RESEARCH_ADD_BUTTON_WIDTH = 28
local BUILD_COLUMN_WIDTH = BLUEPRINT_PANEL_WIDTH + COLUMN_SPACING + EXTRA_ITEMS_PANEL_WIDTH
local MIN_SPLIT_ROW_WIDTH = CONTROL_COLUMN_WIDTH + HEADER_TO_FIELDS_GAP + BUILD_COLUMN_WIDTH + COLUMN_SPACING + RESEARCH_COLUMN_WIDTH + COLUMN_SPACING + TOTAL_PANEL_MIN_WIDTH

M.root_name = "long_pole_plan_editor"
M.close_button_name = "long_pole_close_plan_editor"
M.add_split_button_name = "long_pole_add_split"
M.save_plan_button_name = "long_pole_save_plan"
M.plan_name_field_name = "long_pole_plan_name"
M.split_list_name = "long_pole_split_list"
M.move_split_up_name = "long_pole_move_split_up"
M.move_split_down_name = "long_pole_move_split_down"
M.delete_split_button_name = "long_pole_delete_split"
M.cycle_split_surface_name = "long_pole_cycle_split_surface"
M.add_blueprint_button_name = "long_pole_add_blueprint"
M.replace_blueprint_button_name = "long_pole_replace_blueprint"
M.remove_blueprint_button_name = "long_pole_remove_blueprint"
M.extra_item_cell_button_name = "long_pole_extra_item_cell"
M.research_cell_button_name = "long_pole_research_cell"
M.add_research_button_name = "long_pole_add_research"
M.research_picker_name = "long_pole_research_picker"
M.name_field_name = "long_pole_split_name"
M.notes_field_name = "long_pole_split_notes"
M.toggle_notes_button_name = "long_pole_toggle_notes"

local TITLEBAR_NAME = "long_pole_plan_editor_titlebar"
local CONTENT_NAME = "long_pole_plan_editor_content"
local SHARED_HEADER_NAME = "long_pole_plan_editor_headers"
local EMPTY_SPLIT_LIST_NAME = "long_pole_split_list_empty"
local SPLIT_ROW_NAME_PREFIX = "long_pole_split_row_"
local SPLIT_ROW_BODY_NAME = "long_pole_split_row_body"
local SPLIT_ROW_NAME_ROW_NAME = "long_pole_split_name_row"
local SPLIT_ROW_INDEX_LABEL_NAME = "long_pole_split_index"
local SPLIT_ROW_ACTION_ROW_NAME = "long_pole_split_action_row"
local SPLIT_ROW_DETAIL_ROW_NAME = "long_pole_split_detail_row"
local SPLIT_ROW_FIELDS_NAME = "long_pole_split_fields"
local SPLIT_ROW_NOTES_DRAWER_NAME = "long_pole_split_notes_drawer"

-- This editor is intentionally dense. Most of the refresh logic below exists to
-- keep text focus and scroll positions stable while still letting the rest of
-- the row rebuild aggressively when the underlying split changes.

local function safe_index(root, key)
  if root == nil then
    return nil
  end

  local ok, value = pcall(function()
    return root[key]
  end)
  if ok then
    return value
  end

  return nil
end

local function destroy_children(element)
  for _, child in pairs(element.children) do
    child.destroy()
  end
end

local function count_grid_rows(entry_count, column_count)
  if entry_count <= 0 then
    return 1
  end

  return math.ceil(entry_count / column_count)
end

local function compute_grid_height(entry_count, column_count, slot_size)
  local rows = count_grid_rows(entry_count, column_count)
  return rows * slot_size + ((rows - 1) * GRID_VERTICAL_SPACING) + GRID_CHROME_HEIGHT
end

local function compute_window_dimensions(player)
  local width = math.floor((player.display_resolution.width / player.display_scale) * 0.94)
  local height = math.floor((player.display_resolution.height / player.display_scale) * 0.86)
  return math.max(1080, width), math.max(680, height)
end

local function ensure_editor_state(state)
  state.editor_notes_expanded = state.editor_notes_expanded or {}
  state.editor_raw_cost_errors = state.editor_raw_cost_errors or {}
  state.editor_research_picker_options = state.editor_research_picker_options or {}
end

local function available_surfaces()
  if rawget(_G, "script") and script.active_mods and script.active_mods["space-age"] then
    return {"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"}
  end

  return {"nauvis"}
end

local function normalize_split_surface(split)
  local surfaces = available_surfaces()
  for _, surface_name in ipairs(surfaces) do
    if split.surface == surface_name then
      return surface_name
    end
  end

  return surfaces[1]
end

local function next_surface_name(current_surface)
  local surfaces = available_surfaces()
  local current_index = 1
  for index, surface_name in ipairs(surfaces) do
    if surface_name == current_surface then
      current_index = index
      break
    end
  end

  return surfaces[(current_index % #surfaces) + 1]
end

local function surface_sprite_path(surface_name)
  return "space-location/" .. surface_name
end

local function format_surface_caption(surface_name)
  return (surface_name:gsub("^%l", string.upper))
end

local function raw_cost_error_entry(error_message)
  return {
    sprite = "virtual-signal/signal-X",
    tooltip = error_message or "Raw resource cost could not be calculated."
  }
end

local function try_index(root, key)
  if root == nil then
    return nil
  end

  local ok, value = pcall(function()
    return root[key]
  end)
  if ok then
    return value
  end

  return nil
end

local function get_technology_prototypes()
  local runtime_technology_prototypes = try_index(prototypes, "technology")
  if runtime_technology_prototypes then
    return runtime_technology_prototypes
  end

  return try_index(game, "technology_prototypes") or {}
end

local function is_right_click(event)
  return event and event.button == defines.mouse_button_type.right
end

local function report_raw_cost_error(player, state, split, error_message)
  ensure_editor_state(state)
  local split_id = split and split.id or "unknown"
  local player_errors = state.editor_raw_cost_errors[player.index] or {}
  state.editor_raw_cost_errors[player.index] = player_errors

  -- Raw-cost failures can happen on every refresh tick after an edit. Only print
  -- a new message when the error actually changes so the player chat log stays usable.
  if player_errors[split_id] ~= error_message then
    player_errors[split_id] = error_message
    player.print(error_message)
  end
end

local function clear_raw_cost_error(player, state, split)
  ensure_editor_state(state)
  local player_errors = state.editor_raw_cost_errors[player.index]
  if not player_errors or not split then
    return
  end

  player_errors[split.id] = nil
end

local function style_compact_button(button, width, height)
  button.style.width = width
  button.style.height = height or width
  button.style.left_padding = 0
  button.style.right_padding = 0
  button.style.top_padding = 0
  button.style.bottom_padding = 0
end

local function add_header_gap(parent, width)
  local gap = parent.add({
    type = "empty-widget"
  })
  gap.style.width = width
  gap.style.height = 1
  return gap
end

local function add_header_label(parent, caption, width, stretch)
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

local function effective_plan_name(name)
  local trimmed = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if trimmed == "" then
    return "Untitled Plan"
  end

  return trimmed
end

local function display_plan_name(name)
  if name == nil then
    return "Untitled Plan"
  end

  return name
end

local function build_extra_item_entries(split)
  local entries = {}
  for item_index, item in ipairs(split.items or {}) do
    entries[#entries + 1] = {
      name = item.name,
      count = item.count or 1,
      tooltip = item.name and item.name ~= ""
        and {"", item.name, " x", tostring(item.count or 1), "\nLeft-click to edit. Right-click to remove."}
        or "Click to configure this item slot."
    }
  end
  return entries
end

local function open_extra_item_dialog(player, state, split_id, item_index)
  local split = tracker.get_split_by_id(state, split_id)
  if not split then
    return false
  end

  local item = item_index and split.items[item_index] or nil
  item_quantity_dialog.open(player, state, {
    title = item and "Edit Extra Item" or "Add Extra Item",
    elem_type = "item",
    elem_value = item and item.name or nil,
    count = item and item.count or 1,
    context = {
      kind = "split-extra-item",
      split_id = split_id,
      item_index = item_index
    }
  })
  return true
end

local function apply_item_dialog_result(state, dialog_result)
  local context = dialog_result.context or {}
  if context.kind ~= "split-extra-item" then
    return false
  end

  if not dialog_result.elem_value then
    if context.item_index then
      return tracker.remove_split_item_by_id(state, context.split_id, context.item_index)
    end
    return false
  end

  local item = {
    name = dialog_result.elem_value,
    count = dialog_result.count
  }

  if context.item_index then
    return tracker.replace_split_item_by_id(state, context.split_id, context.item_index, item)
  end

  return tracker.add_split_item_by_id(state, context.split_id, item)
end

local function ensure_window(player)
  local frame = player.gui.screen[M.root_name]
  if frame then
    local width, height = compute_window_dimensions(player)
    frame.style.width = width
    frame.style.height = height
    return frame, width
  end

  frame = player.gui.screen.add({
    type = "frame",
    name = M.root_name,
    direction = "vertical"
  })
  frame.auto_center = true

  local width, height = compute_window_dimensions(player)
  frame.style.width = width
  frame.style.height = height

  return frame, width
end

local function split_row_element_name(split_id)
  return SPLIT_ROW_NAME_PREFIX .. tostring(split_id)
end

local function technology_display_name(prototype, technology_name)
  if prototype and prototype.localised_name then
    return prototype.localised_name
  end

  return technology_name
end

local function technology_sprite(technology_name, prototype)
  if prototype then
    return "technology/" .. technology_name
  end

  return "virtual-signal/signal-X"
end

local function technology_picker_choices(split)
  local selected = {}
  for _, technology in ipairs(split.technologies or {}) do
    if technology.name and technology.name ~= "" then
      selected[technology.name] = true
    end
  end

  local names = {}
  local technology_prototypes = get_technology_prototypes()
  for technology_name, prototype in pairs(technology_prototypes) do
    if not selected[technology_name] and prototype then
      names[#names + 1] = technology_name
    end
  end

  table.sort(names, function(a, b)
    local a_prototype = technology_prototypes[a]
    local b_prototype = technology_prototypes[b]
    local a_order = (a_prototype and a_prototype.order) or ""
    local b_order = (b_prototype and b_prototype.order) or ""
    if a_order == b_order then
      return a < b
    end
    return a_order < b_order
  end)

  local captions = {}
  for index, technology_name in ipairs(names) do
    captions[index] = technology_display_name(technology_prototypes[technology_name], technology_name)
  end

  return names, captions, technology_prototypes
end

local function build_research_entries(split, technology_prototypes)
  local entries = {}

  for technology_index, technology in ipairs(split.technologies or {}) do
    local technology_name = technology.name
    if technology_name and technology_name ~= "" then
      local prototype = technology_prototypes[technology_name]
      local tooltip
      if prototype then
        local pack_names = {}
        for _, ingredient in ipairs(prototype.research_unit_ingredients or {}) do
          pack_names[#pack_names + 1] = ("%s x%d"):format(ingredient.name, ingredient.amount or ingredient.count or 0)
        end

        tooltip = {
          "",
          technology_display_name(prototype, technology_name),
          "\n",
          technology_name,
          "\n",
          "Units: ",
          tostring(prototype.research_unit_count or 0),
          (#pack_names > 0 and {"", "\n", table.concat(pack_names, "\n")} or ""),
          "\nClick to remove this research from the split."
        }
      else
        tooltip = {"", technology_name, "\nTechnology prototype not found.\nClick to remove this research from the split."}
      end

      entries[#entries + 1] = {
        name = technology_name,
        sprite = technology_sprite(technology_name, prototype),
        tooltip = tooltip,
        technology_index = technology_index
      }
    end
  end

  return entries
end

local function get_held_blueprint(player)
  local resolved, error_message = cursor_blueprint_source.resolve_selected_blueprint(player)
  if not resolved then
    return nil, error_message
  end

  local source = resolved.source
  local entities = source.get_blueprint_entities and source.get_blueprint_entities() or {}
  local entity_count = source.get_blueprint_entity_count and source.get_blueprint_entity_count() or 0
  local provisional_symlink = {
    library_root = resolved.library_root or "player-blueprints",
    inside_books = resolved.inside_books or nil,
    blueprint_slot = resolved.source_book_active_index
  }
  local blueprint_name = safe_index(source, "label")
  if not blueprint_name or blueprint_name == "" then
    blueprint_name = "Unnamed Blueprint"
  end

  provisional_symlink.blueprint_name = blueprint_name
  local extracted_fingerprint = blueprint_fingerprint.extract_blueprint_fingerprint({
    name = blueprint_name,
    entity_summary = blueprint_entity_summary.summarize_entities(entities),
    entity_count = entity_count
  }, provisional_symlink)
  local library_match = blueprint_library.find_blueprint_symlink_by_fingerprint(player, extracted_fingerprint, game)
  if (not safe_index(source, "label") or safe_index(source, "label") == "") and library_match and library_match.blueprint_name and library_match.blueprint_name ~= "" then
    blueprint_name = library_match.blueprint_name
  end

  return {
    name = blueprint_name,
    entity_count = entity_count,
    entity_summary = extracted_fingerprint.entity_summary,
    blueprint_fingerprint = extracted_fingerprint.blueprint_fingerprint,
    library_root = library_match and library_match.library_root or "player-blueprints",
    inside_books = library_match and library_match.inside_books or nil,
    blueprint_slot = library_match and library_match.blueprint_slot or resolved.source_book_active_index,
    source_book_label = resolved.source_book_label,
    source_book_active_index = resolved.source_book_active_index
  }, nil
end

local function add_blueprint_sources(parent, split)
  local panel = parent.add({
    type = "flow",
    direction = "vertical"
  })
  panel.style.width = BLUEPRINT_PANEL_WIDTH
  panel.style.vertically_stretchable = true

  local header = panel.add({
    type = "flow",
    direction = "horizontal"
  })
  header.style.horizontally_stretchable = true

  local label = header.add({
    type = "label",
    caption = "Constructed Blueprints"
  })
  label.style = "semibold_label"

  local spacer = header.add({
    type = "empty-widget"
  })
  spacer.style.horizontally_stretchable = true

  local add_button = header.add({
    type = "button",
    name = M.add_blueprint_button_name,
    caption = "Use Held",
    tags = {split_id = split.id}
  })
  add_button.tooltip = "Capture a held blueprint whose entities must be placed before this split is complete."
  add_button.style.width = 110
  add_button.style.height = PANEL_HEADER_HEIGHT

  local list = panel.add({
    type = "scroll-pane",
    horizontal_scroll_policy = "never",
    vertical_scroll_policy = "auto"
  })
  list.style.horizontally_stretchable = true
  list.style.vertically_stretchable = true
  list.style.top_margin = 6

  local chips = list.add({
    type = "flow",
    direction = "vertical"
  })
  chips.style.vertical_spacing = 6

  if #split.blueprints == 0 then
    local empty = chips.add({
      type = "label",
      caption = "No required blueprints"
    })
    empty.style.font_color = {0.8, 0.8, 0.8}
    empty.style.top_margin = 4
  end

  for blueprint_index, blueprint in ipairs(split.blueprints) do
    local chip = chips.add({
      type = "flow",
      direction = "horizontal"
    })
    chip.style.horizontally_stretchable = true
    chip.style.height = BLUEPRINT_CHIP_HEIGHT

    local icon = chip.add({
      type = "sprite-button",
      name = M.replace_blueprint_button_name,
      sprite = "item/blueprint",
      tags = {split_id = split.id, blueprint_index = blueprint_index}
    })
    icon.tooltip = "Click while holding a blueprint to replace this linked blueprint."
    icon.style.width = 36
    icon.style.height = 36
    icon.style.top_margin = 5

    local text = chip.add({
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
    name.style.maximal_width = 220

    local meta = text.add({
      type = "label",
      caption = ("%d entities"):format(blueprint.entity_count or 0)
    })
    meta.style.font_color = {0.75, 0.75, 0.75}

    local remove_button = chip.add({
      type = "sprite-button",
      name = M.remove_blueprint_button_name,
      sprite = "utility/trash",
      tags = {split_id = split.id, blueprint_index = blueprint_index}
    })
    remove_button.style = "tool_button"
    remove_button.style.width = 28
    remove_button.style.height = 28
    remove_button.tooltip = "Remove this linked blueprint from the split."
    remove_button.style.top_margin = 4
  end
end

local function add_extra_items_panel(parent, split)
  local panel = parent.add({
    type = "flow",
    direction = "vertical"
  })
  panel.style.width = EXTRA_ITEMS_PANEL_WIDTH
  panel.style.vertically_stretchable = true

  local header = panel.add({
    type = "flow",
    direction = "horizontal"
  })
  header.style.horizontally_stretchable = true

  local label = header.add({
    type = "label",
    caption = "Extra Stock"
  })
  label.style = "semibold_label"

  slot_grid.add(panel, build_extra_item_entries(split), {
    top_margin = 6,
    minimal_height = compute_grid_height(math.max(1, #split.items + 1), EXTRA_ITEM_GRID_COLUMNS, EXTRA_ITEM_SLOT_SIZE),
    maximal_height = compute_grid_height(math.max(1, #split.items + 1), EXTRA_ITEM_GRID_COLUMNS, EXTRA_ITEM_SLOT_SIZE),
    column_count = EXTRA_ITEM_GRID_COLUMNS,
    slot_size = EXTRA_ITEM_SLOT_SIZE,
    horizontal_spacing = 6,
    vertical_spacing = 6,
    vertical_scroll_policy = "never",
    horizontal_scroll_policy = "never",
    vertically_stretchable = false,
    minimum_entry_count = math.max(1, #split.items + 1),
    button_name = M.extra_item_cell_button_name,
    empty_tooltip = "Click to add an extra stock target for this split.",
    build_tags = function(entry, index)
      return {
        split_id = split.id,
        item_index = entry and index or nil
      }
    end
  })
end

local function add_total_panel(parent, state, split)
  local panel = parent.add({
    type = "flow",
    direction = "vertical"
  })
  panel.style.horizontally_stretchable = true
  panel.style.minimal_width = TOTAL_PANEL_MIN_WIDTH

  local label = panel.add({
    type = "label",
    caption = "Total"
  })
  label.style = "semibold_label"

  local summary = build_requirements.summarize_split(split)

  if #summary == 0 then
    local player = game.get_player(parent.player_index)
    if player then
      clear_raw_cost_error(player, state, split)
    end

    local empty = panel.add({
      type = "label",
      caption = "No build requirements yet."
    })
    empty.style.font_color = {0.8, 0.8, 0.8}
    empty.style.top_margin = 8
    panel.style.minimal_height = 96
    return panel
  end

  slot_grid.add(panel, summary, {
    top_margin = 6,
    minimal_height = compute_grid_height(#summary, BUILD_GRID_COLUMNS, BUILD_GRID_SLOT_SIZE),
    maximal_height = compute_grid_height(#summary, BUILD_GRID_COLUMNS, BUILD_GRID_SLOT_SIZE),
    column_count = BUILD_GRID_COLUMNS,
    slot_size = BUILD_GRID_SLOT_SIZE,
    vertical_scroll_policy = "never",
    horizontal_scroll_policy = "never",
    vertically_stretchable = false
  })

  local raw_cost_label = panel.add({
    type = "label",
    caption = "Raw Cost"
  })
  raw_cost_label.style = "semibold_label"
  raw_cost_label.style.top_margin = 10

  local raw_summary, raw_error = build_requirements.summarize_raw_cost(split)
  if raw_error then
    local player = game.get_player(parent.player_index)
    if player then
      report_raw_cost_error(player, state, split, raw_error)
    end
    raw_summary = {raw_cost_error_entry(raw_error)}
  else
    local player = game.get_player(parent.player_index)
    if player then
      clear_raw_cost_error(player, state, split)
    end
  end

  if #raw_summary == 0 then
    local raw_empty = panel.add({
      type = "label",
      caption = "No raw resource cost yet."
    })
    raw_empty.style.font_color = {0.8, 0.8, 0.8}
    raw_empty.style.top_margin = 6
    return panel
  end

  slot_grid.add(panel, raw_summary, {
    top_margin = 6,
    minimal_height = compute_grid_height(#raw_summary, BUILD_GRID_COLUMNS, BUILD_GRID_SLOT_SIZE),
    maximal_height = compute_grid_height(#raw_summary, BUILD_GRID_COLUMNS, BUILD_GRID_SLOT_SIZE),
    column_count = BUILD_GRID_COLUMNS,
    slot_size = BUILD_GRID_SLOT_SIZE,
    vertical_scroll_policy = "never",
    horizontal_scroll_policy = "never",
    vertically_stretchable = false
  })

  return panel
end

local function add_research_panel(parent, state, split)
  local panel = parent.add({
    type = "flow",
    direction = "vertical"
  })
  panel.style.horizontally_stretchable = false
  panel.style.width = RESEARCH_COLUMN_WIDTH

  local label = panel.add({
    type = "label",
    caption = "Completed Research"
  })
  label.style = "semibold_label"
  local technology_names, captions, technology_prototypes = technology_picker_choices(split)
  local research_entries = build_research_entries(split, technology_prototypes)
  local player_picker_options = state.editor_research_picker_options[parent.player_index] or {}
  state.editor_research_picker_options[parent.player_index] = player_picker_options
  player_picker_options[split.id] = technology_names
  local picker_items = captions
  if #picker_items == 0 then
    picker_items = {"No research available"}
  end

  if #research_entries == 0 then
    local empty = panel.add({
      type = "label",
      caption = "No research required."
    })
    empty.style.font_color = {0.8, 0.8, 0.8}
    empty.style.top_margin = 8
  else
    slot_grid.add(panel, research_entries, {
      top_margin = 6,
      minimal_height = compute_grid_height(#research_entries, RESEARCH_GRID_COLUMNS, RESEARCH_SLOT_SIZE),
      maximal_height = compute_grid_height(#research_entries, RESEARCH_GRID_COLUMNS, RESEARCH_SLOT_SIZE),
      column_count = RESEARCH_GRID_COLUMNS,
      slot_size = RESEARCH_SLOT_SIZE,
      horizontal_spacing = 6,
      vertical_spacing = 6,
      vertical_scroll_policy = "never",
      horizontal_scroll_policy = "never",
      vertically_stretchable = false,
      button_name = M.research_cell_button_name,
      build_tags = function(entry)
        return {
          split_id = split.id,
          technology_index = entry.technology_index
        }
      end
    })
  end

  local controls = panel.add({
    type = "flow",
    direction = "horizontal"
  })
  controls.style.top_margin = 8
  controls.style.horizontal_spacing = 6
  controls.style.horizontally_stretchable = true

  local picker = controls.add({
    type = "drop-down",
    name = M.research_picker_name,
    items = picker_items,
    selected_index = 1,
    tags = {split_id = split.id}
  })
  picker.style.width = RESEARCH_COLUMN_WIDTH - 62
  picker.enabled = #captions > 0
  picker.tooltip = #captions > 0
    and "Choose a technology that must be completed before this split is done."
    or "All available technologies are already selected."

  local add_button = controls.add({
    type = "button",
    name = M.add_research_button_name,
    caption = "+",
    tags = {split_id = split.id}
  })
  style_compact_button(add_button, RESEARCH_ADD_BUTTON_WIDTH, PANEL_HEADER_HEIGHT)
  add_button.enabled = #technology_names > 0
  add_button.tooltip = "Add a technology that must be completed before this split is done."

  return panel
end

local function add_notes_drawer(parent, split)
  local drawer = parent.add({
    type = "flow",
    name = SPLIT_ROW_NOTES_DRAWER_NAME,
    direction = "vertical"
  })
  drawer.style.horizontally_stretchable = true
  drawer.style.top_margin = 6

  local notes = drawer.add({
    type = "text-box",
    name = M.notes_field_name,
    text = split.notes,
    tags = {split_id = split.id}
  })
  notes.style.horizontally_stretchable = true
  notes.style.minimal_height = 84
  notes.style.maximal_height = 84
  notes.tooltip = "Planning notes, staged blueprint rules, and reminders."
end

local function add_shared_column_headers(parent, row_width)
  local header_row = parent.add({
    type = "flow",
    name = SHARED_HEADER_NAME,
    direction = "horizontal"
  })
  header_row.style.horizontally_stretchable = true
  header_row.style.top_margin = 6
  header_row.style.horizontal_spacing = 0
  if row_width then
    header_row.style.width = row_width
  end

  add_header_label(header_row, "Split", CONTROL_COLUMN_WIDTH, false)
  add_header_gap(header_row, HEADER_TO_FIELDS_GAP)
  add_header_label(header_row, "Placement Goals", BUILD_COLUMN_WIDTH, false)
  add_header_gap(header_row, COLUMN_SPACING)
  add_header_label(header_row, "Research Goals", RESEARCH_COLUMN_WIDTH, false)
  add_header_gap(header_row, COLUMN_SPACING)
  add_header_label(header_row, "Planning Totals", TOTAL_PANEL_MIN_WIDTH, true)
end

local function build_split_row_contents(outer, state, split_index, split, total_splits)
  local row = outer.add({
    type = "flow",
    name = SPLIT_ROW_BODY_NAME,
    direction = "horizontal",
    tags = {split_id = split.id}
  })
  row.style.horizontally_stretchable = true

  local controls = row.add({
    type = "flow",
    direction = "vertical",
    name = "controls"
  })
  controls.style.minimal_width = CONTROL_COLUMN_WIDTH
  controls.style.maximal_width = CONTROL_COLUMN_WIDTH

  local name_row = controls.add({
    type = "flow",
    name = SPLIT_ROW_NAME_ROW_NAME,
    direction = "horizontal"
  })
  name_row.style.horizontally_stretchable = true
  name_row.style.horizontal_spacing = 6

  local row_label = name_row.add({
    type = "label",
    name = SPLIT_ROW_INDEX_LABEL_NAME,
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
  name_field.style.minimal_width = 120
  name_field.style.maximal_width = 120

  local action_row = controls.add({
    type = "flow",
    name = SPLIT_ROW_ACTION_ROW_NAME,
    direction = "horizontal"
  })
  action_row.style.top_margin = 6
  action_row.style.horizontal_spacing = 6

  local up_button = action_row.add({
    type = "button",
    name = M.move_split_up_name,
    caption = "▲",
    tags = {split_id = split.id}
  })
  style_compact_button(up_button, COMPACT_ICON_BUTTON_SIZE)
  up_button.enabled = split_index > 1

  local down_button = action_row.add({
    type = "button",
    name = M.move_split_down_name,
    caption = "▼",
    tags = {split_id = split.id}
  })
  style_compact_button(down_button, COMPACT_ICON_BUTTON_SIZE)
  down_button.enabled = split_index < total_splits

  local delete_button = action_row.add({
    type = "sprite-button",
    name = M.delete_split_button_name,
    sprite = "utility/trash",
    tags = {split_id = split.id}
  })
  delete_button.style = "red_slot_button"
  delete_button.style.width = COMPACT_ICON_BUTTON_SIZE
  delete_button.style.height = COMPACT_ICON_BUTTON_SIZE
  delete_button.tooltip = "Delete this split."

  local detail_row = controls.add({
    type = "flow",
    name = SPLIT_ROW_DETAIL_ROW_NAME,
    direction = "horizontal"
  })
  detail_row.style.top_margin = 6
  detail_row.style.horizontal_spacing = 6

  split.surface = normalize_split_surface(split)
  local surface_button = detail_row.add({
    type = "sprite-button",
    name = M.cycle_split_surface_name,
    sprite = surface_sprite_path(split.surface),
    tags = {split_id = split.id}
  })
  surface_button.style = "tool_button"
  surface_button.style.width = PLANET_BUTTON_SIZE
  surface_button.style.height = PLANET_BUTTON_SIZE
  surface_button.tooltip = {"", "Surface: ", format_surface_caption(split.surface)}
  surface_button.enabled = #available_surfaces() > 1

  local notes_button = detail_row.add({
    type = "button",
    name = M.toggle_notes_button_name,
    caption = "N",
    tags = {split_id = split.id}
  })
  style_compact_button(notes_button, COMPACT_ICON_BUTTON_SIZE)
  notes_button.tooltip = split.notes ~= "" and "Show or hide notes for this split." or "Add notes for this split."

  local fields = row.add({
    type = "flow",
    name = SPLIT_ROW_FIELDS_NAME,
    direction = "horizontal"
  })
  fields.style.horizontally_stretchable = true
  fields.style.vertically_stretchable = true
  fields.style.horizontal_spacing = COLUMN_SPACING
  fields.style.left_margin = HEADER_TO_FIELDS_GAP

  add_blueprint_sources(fields, split)
  add_extra_items_panel(fields, split)
  add_research_panel(fields, state, split)
  add_total_panel(fields, state, split)

  if split.notes ~= "" or split.notes_expanded then
    add_notes_drawer(outer, split)
  end
end

local function add_split_row(parent, state, split_index, split, total_splits, row_width)
  local outer = parent.add({
    type = "frame",
    name = split_row_element_name(split.id),
    direction = "vertical",
    tags = {split_id = split.id}
  })
  outer.style.horizontally_stretchable = true
  if row_width then
    outer.style.width = row_width
  end
  outer.style.top_margin = 8

  build_split_row_contents(outer, state, split_index, split, total_splits)
  return outer
end

local function ensure_layout(frame, state, window_width)
  local titlebar = frame[TITLEBAR_NAME]
  local content = frame[CONTENT_NAME]
  local split_list = content and content[M.split_list_name] or nil
  local plan_name_field = titlebar and titlebar[M.plan_name_field_name] or nil

  if titlebar and content and split_list and plan_name_field then
    return titlebar, content, split_list
  end

  destroy_children(frame)

  titlebar = frame.add({
    type = "flow",
    name = TITLEBAR_NAME,
    direction = "horizontal"
  })
  titlebar.drag_target = frame
  titlebar.style.horizontally_stretchable = true
  titlebar.style.vertical_align = "center"
  titlebar.style.horizontal_spacing = 8

  plan_name_field = titlebar.add({
    type = "textfield",
    name = M.plan_name_field_name,
    text = display_plan_name(state.plan_name)
  })
  plan_name_field.style.minimal_width = TITLE_FIELD_MIN_WIDTH
  plan_name_field.style.maximal_width = TITLE_FIELD_MAX_WIDTH
  plan_name_field.style.width = math.min(TITLE_FIELD_MAX_WIDTH, math.max(TITLE_FIELD_MIN_WIDTH, window_width - 520))
  plan_name_field.style.height = 28
  plan_name_field.style.left_margin = 8
  plan_name_field.tags = {plan_name = true}
  plan_name_field.tooltip = "Edit the plan name."

  local spacer = titlebar.add({ type = "empty-widget" })
  spacer.style.horizontally_stretchable = true
  spacer.style.height = 24
  spacer.drag_target = frame
  spacer.ignored_by_interaction = true

  titlebar.add({
    type = "button",
    name = M.add_split_button_name,
    caption = "Add Split"
  })

  titlebar.add({
    type = "button",
    name = M.save_plan_button_name,
    caption = "Save to New Book"
  })

  titlebar.add({
    type = "sprite-button",
    name = M.close_button_name,
    sprite = "utility/close",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "frame_action_button"
  })

  content = frame.add({
    type = "flow",
    name = CONTENT_NAME,
    direction = "vertical"
  })
  content.style.horizontally_stretchable = true
  content.style.vertically_stretchable = true
  content.style.top_margin = 6

  local split_row_width = math.max(MIN_SPLIT_ROW_WIDTH, window_width - 72)
  add_shared_column_headers(content, split_row_width)

  split_list = content.add({
    type = "scroll-pane",
    name = M.split_list_name,
    vertical_scroll_policy = "auto"
  })
  split_list.style.vertically_stretchable = true
  split_list.style.horizontally_stretchable = true
  split_list.style.top_margin = 6

  return titlebar, content, split_list
end

local function split_list_needs_rebuild(split_list, state)
  if #state.splits == 0 then
    return #split_list.children ~= 1 or split_list[EMPTY_SPLIT_LIST_NAME] == nil
  end

  if split_list[EMPTY_SPLIT_LIST_NAME] ~= nil then
    return true
  end

  if #split_list.children ~= #state.splits then
    return true
  end

  for index, split in ipairs(state.splits) do
    local row = split_list.children[index]
    -- A split-id mismatch means rows were reordered or replaced. Rebuilding is
    -- cheaper than trying to surgically retag a now-wrong widget tree.
    if not row or not row.valid or not row.tags or row.tags.split_id ~= split.id then
      return true
    end
  end

  return false
end

local function find_split_row(split_list, split_id)
  for _, child in ipairs(split_list.children or {}) do
    if child.valid and child.tags and child.tags.split_id == split_id then
      return child
    end
  end

  return nil
end

local function sync_notes_drawer(outer, split)
  local drawer = outer[SPLIT_ROW_NOTES_DRAWER_NAME]
  local should_show = split.notes ~= "" or split.notes_expanded

  if not should_show then
    if drawer then
      drawer.destroy()
    end
    return
  end

  if not drawer then
    add_notes_drawer(outer, split)
    return
  end

  local notes_field = drawer[M.notes_field_name]
  if notes_field then
    notes_field.tags = {split_id = split.id}
    if notes_field.text ~= split.notes then
      notes_field.text = split.notes
    end
  end
end

local function sync_split_row(outer, state, split_index, split, total_splits, row_width)
  outer.tags = {split_id = split.id}
  outer.style.horizontally_stretchable = true
  outer.style.top_margin = 8
  if row_width then
    outer.style.width = row_width
  end

  local row = outer[SPLIT_ROW_BODY_NAME]
  local controls = row and row.controls or nil
  local name_row = controls and controls[SPLIT_ROW_NAME_ROW_NAME] or nil
  local action_row = controls and controls[SPLIT_ROW_ACTION_ROW_NAME] or nil
  local detail_row = controls and controls[SPLIT_ROW_DETAIL_ROW_NAME] or nil
  local fields = row and row[SPLIT_ROW_FIELDS_NAME] or nil

  if not (row and controls and name_row and action_row and detail_row and fields) then
    destroy_children(outer)
    build_split_row_contents(outer, state, split_index, split, total_splits)
    return
  end

  row.tags = {split_id = split.id}

  local row_label = name_row[SPLIT_ROW_INDEX_LABEL_NAME]
  if row_label then
    row_label.caption = "#" .. split_index
  end

  local name_field = name_row[M.name_field_name]
  if name_field then
    name_field.tags = {split_id = split.id}
    if name_field.text ~= split.name then
      name_field.text = split.name
    end
  end

  local up_button = action_row[M.move_split_up_name]
  if up_button then
    up_button.tags = {split_id = split.id}
    up_button.enabled = split_index > 1
  end

  local down_button = action_row[M.move_split_down_name]
  if down_button then
    down_button.tags = {split_id = split.id}
    down_button.enabled = split_index < total_splits
  end

  local delete_button = action_row[M.delete_split_button_name]
  if delete_button then
    delete_button.tags = {split_id = split.id}
  end

  split.surface = normalize_split_surface(split)
  local surface_button = detail_row[M.cycle_split_surface_name]
  if surface_button then
    surface_button.tags = {split_id = split.id}
    surface_button.sprite = surface_sprite_path(split.surface)
    surface_button.tooltip = {"", "Surface: ", format_surface_caption(split.surface)}
    surface_button.enabled = #available_surfaces() > 1
  end

  local notes_button = detail_row[M.toggle_notes_button_name]
  if notes_button then
    notes_button.tags = {split_id = split.id}
    notes_button.tooltip = split.notes ~= "" and "Show or hide notes for this split." or "Add notes for this split."
  end

  -- Rebuild the dense planning panels every refresh, but keep the outer row and
  -- text widgets alive so typing in names/notes does not constantly lose focus.
  destroy_children(fields)
  add_blueprint_sources(fields, split)
  add_extra_items_panel(fields, split)
  add_research_panel(fields, state, split)
  add_total_panel(fields, state, split)
  sync_notes_drawer(outer, split)
end

local function sync_split_list(player, state, split_list, row_width)
  -- Picker options are rebuilt from the visible split rows so stale technology
  -- indices never survive a reorder or deletion.
  state.editor_research_picker_options[player.index] = {}

  if split_list_needs_rebuild(split_list, state) then
    destroy_children(split_list)

    if #state.splits == 0 then
      local empty_state = split_list.add({
        type = "label",
        name = EMPTY_SPLIT_LIST_NAME,
        caption = "No splits yet. Click Add Split to start building this run."
      })
      empty_state.style.single_line = false
      empty_state.style.font_color = {0.8, 0.8, 0.8}
      empty_state.style.top_margin = 12
      return
    end

    for index, split in ipairs(state.splits) do
      split.notes_expanded = state.editor_notes_expanded[split.id] or false
      add_split_row(split_list, state, index, split, #state.splits, row_width)
    end
    return
  end

  if #state.splits == 0 then
    return
  end

  for index, split in ipairs(state.splits) do
    split.notes_expanded = state.editor_notes_expanded[split.id] or false
    local outer = split_list.children[index]
    if not outer or not outer.valid then
      return
    end
    sync_split_row(outer, state, index, split, #state.splits, row_width)
  end
end

local function refresh_split_row_by_id(player, state, split_id)
  local frame = player.gui.screen[M.root_name]
  if not frame then
    return false
  end

  local content = frame[CONTENT_NAME]
  local split_list = content and content[M.split_list_name] or nil
  local split, split_index = tracker.get_split_by_id(state, split_id)
  if not (split_list and split and split_index) then
    return false
  end

  local outer = find_split_row(split_list, split_id)
  if not outer then
    return false
  end

  split.notes_expanded = state.editor_notes_expanded[split.id] or false
  local _, window_width = ensure_window(player)
  local header_row = content[SHARED_HEADER_NAME]
  local split_row_width = math.max(MIN_SPLIT_ROW_WIDTH, window_width - 72)
  if header_row then
    header_row.style.width = split_row_width
  end
  local player_picker_options = state.editor_research_picker_options[player.index] or {}
  state.editor_research_picker_options[player.index] = player_picker_options
  player_picker_options[split.id] = nil
  sync_split_row(outer, state, split_index, split, #state.splits, split_row_width)
  return true
end

function M.open(player, state)
  local frame = ensure_window(player)
  M.refresh(player, state)
  player.opened = frame
end

function M.close(player, state)
  if state then
    item_quantity_dialog.close(player, state)
  else
    local dialog = player.gui.screen[item_quantity_dialog.root_name]
    if dialog then
      dialog.destroy()
    end
  end
  local frame = player.gui.screen[M.root_name]
  if frame then
    frame.destroy()
  end
end

function M.refresh(player, state)
  local existing_frame = player.gui.screen[M.root_name]
  if not existing_frame then
    return
  end

  local frame, window_width = ensure_window(player)

  ensure_editor_state(state)
  local titlebar, content, split_list = ensure_layout(frame, state, window_width)
  local plan_name_field = titlebar[M.plan_name_field_name]
  if plan_name_field then
    local displayed_name = display_plan_name(state.plan_name)
    if plan_name_field.text ~= displayed_name then
      plan_name_field.text = displayed_name
    end
    plan_name_field.style.width = math.min(TITLE_FIELD_MAX_WIDTH, math.max(TITLE_FIELD_MIN_WIDTH, window_width - 520))
  end

  local split_row_width = math.max(MIN_SPLIT_ROW_WIDTH, window_width - 72)
  local header_row = content[SHARED_HEADER_NAME]
  if header_row then
    header_row.style.width = split_row_width
  end

  sync_split_list(player, state, split_list, split_row_width)
end

local function refresh_split_row_or_editor(player, state, split_id)
  if split_id and refresh_split_row_by_id(player, state, split_id) then
    return
  end

  M.refresh(player, state)
end

function M.handle_click(player, state, element, event)
  local dialog_result = item_quantity_dialog.handle_click(player, state, element)
  if dialog_result then
    if dialog_result.action == "confirm" then
      local applied = apply_item_dialog_result(state, dialog_result)
      if applied then
        refresh_split_row_or_editor(player, state, dialog_result.context and dialog_result.context.split_id or nil)
        return "refresh-split-viewer"
      end
      return "handled"
    end
    return "handled"
  end

  if element.name == M.close_button_name then
    M.close(player, state)
    return false
  end

  if element.name == "long_pole_open_plan_editor" then
    M.open(player, state)
    return "handled"
  end

  if element.name == M.add_split_button_name then
    tracker.add_split(state)
    M.refresh(player, state)
    return "refresh-split-viewer"
  end

  if element.name == M.save_plan_button_name then
    state.plan_name = effective_plan_name(state.plan_name)
    local ok, error_message = plan_storage.export_plan_to_cursor(player, state)
    if not ok then
      player.print(error_message)
      return false
    end

    M.refresh(player, state)
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
      local changed = tracker.add_split_blueprint_by_id(state, element.tags.split_id, blueprint)
      if changed then
        refresh_split_row_or_editor(player, state, element.tags.split_id)
        return "refresh-split-viewer"
      end
      return false
    end

    local changed = tracker.replace_split_blueprint_by_id(
      state,
      element.tags.split_id,
      element.tags.blueprint_index,
      blueprint
    )
    if changed then
      refresh_split_row_or_editor(player, state, element.tags.split_id)
      return "refresh-split-viewer"
    end
    return false
  end

  if element.name == M.remove_blueprint_button_name then
    local changed = tracker.remove_split_blueprint_by_id(state, element.tags.split_id, element.tags.blueprint_index)
    if changed then
      refresh_split_row_or_editor(player, state, element.tags.split_id)
      return "refresh-split-viewer"
    end
    return false
  end

  if element.name == M.delete_split_button_name then
    ensure_editor_state(state)
    local split_id = element.tags.split_id
    state.editor_notes_expanded[split_id] = nil

    local player_errors = state.editor_raw_cost_errors[player.index]
    if player_errors then
      player_errors[split_id] = nil
    end

    local changed = tracker.remove_split_by_id(state, split_id)
    if changed then
      M.refresh(player, state)
      return "refresh-split-viewer"
    end
    return false
  end

  if element.name == M.toggle_notes_button_name then
    ensure_editor_state(state)
    local split_id = element.tags.split_id
    state.editor_notes_expanded[split_id] = not state.editor_notes_expanded[split_id]
    refresh_split_row_or_editor(player, state, split_id)
    return "handled"
  end

  if element.name == M.cycle_split_surface_name then
    local split = tracker.get_split_by_id(state, element.tags.split_id)
    if not split then
      return false
    end

    local changed = tracker.set_split_surface_by_id(
      state,
      element.tags.split_id,
      next_surface_name(normalize_split_surface(split))
    )
    if changed then
      refresh_split_row_or_editor(player, state, element.tags.split_id)
      return "refresh-split-viewer"
    end
    return false
  end

  if slot_grid.matches_action(element, M.extra_item_cell_button_name) then
    if is_right_click(event) and element.tags.item_index then
      local changed = tracker.remove_split_item_by_id(state, element.tags.split_id, element.tags.item_index)
      if changed then
        refresh_split_row_or_editor(player, state, element.tags.split_id)
        return "refresh-split-viewer"
      end
      return false
    end

    open_extra_item_dialog(player, state, element.tags.split_id, element.tags.item_index)
    return "handled"
  end

  if slot_grid.matches_action(element, M.research_cell_button_name) then
    if not element.tags.technology_index then
      return false
    end

    local changed = tracker.remove_split_technology_by_id(state, element.tags.split_id, element.tags.technology_index)
    if changed then
      refresh_split_row_or_editor(player, state, element.tags.split_id)
      return "refresh-split-viewer"
    end
    return false
  end

  if element.name == M.add_research_button_name then
    local picker = element.parent and element.parent[M.research_picker_name] or nil
    local selection_state = picker and picker.valid and picker.selected_index or 0
    local player_picker_options = state.editor_research_picker_options[player.index] or {}
    local technology_names = player_picker_options[element.tags.split_id] or {}
    local technology_name = technology_names[selection_state]
    if not technology_name then
      return false
    end

    local changed = tracker.add_split_technology_by_id(state, element.tags.split_id, {name = technology_name})
    if changed then
      refresh_split_row_or_editor(player, state, element.tags.split_id)
      return "refresh-split-viewer"
    end
    return false
  end

  if element.name == M.move_split_up_name then
    local split_index = tracker.find_split_index_by_id(state, element.tags.split_id)
    if not split_index then
      return false
    end
    local changed = tracker.move_split(state, split_index, split_index - 1)
    if changed then
      M.refresh(player, state)
      return "refresh-split-viewer"
    end
    return false
  end

  if element.name == M.move_split_down_name then
    local split_index = tracker.find_split_index_by_id(state, element.tags.split_id)
    if not split_index then
      return false
    end
    local changed = tracker.move_split(state, split_index, split_index + 1)
    if changed then
      M.refresh(player, state)
      return "refresh-split-viewer"
    end
    return false
  end

  return false
end

function M.handle_text_changed(_player, state, element)
  if item_quantity_dialog.handle_text_changed(_player, state, element) then
    return false
  end

  if element.name == M.plan_name_field_name then
    state.plan_name = element.text
    return false
  end

  local split_id = element.tags.split_id
  if not split_id then
    return false
  end

  if element.name == M.name_field_name then
    if tracker.rename_split_by_id(state, split_id, element.text) then
      return "refresh-split-viewer"
    end
    return false
  end

  if element.name == M.notes_field_name then
    tracker.set_split_notes_by_id(state, split_id, element.text)
    return false
  end

  return false
end

function M.handle_elem_changed(_player, state, element)
  if item_quantity_dialog.handle_elem_changed(_player, state, element) then
    return false
  end

  return false
end

function M.handle_value_changed(player, state, element)
  if item_quantity_dialog.handle_value_changed(player, state, element) then
    return false
  end

  return false
end

function M.handle_confirmed(player, state, element)
  local dialog_result = item_quantity_dialog.handle_confirmed(player, state, element)
  if dialog_result then
    if dialog_result.action == "confirm" then
      local applied = apply_item_dialog_result(state, dialog_result)
      if applied then
        refresh_split_row_or_editor(player, state, dialog_result.context and dialog_result.context.split_id or nil)
        return "refresh-split-viewer"
      end
      return "handled"
    end
    return "handled"
  end

  return false
end

return M
