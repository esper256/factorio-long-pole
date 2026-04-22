local blueprint_entity_summary = require("util.blueprint_entity_summary")
local blueprint_fingerprint = require("util.blueprint_fingerprint")
local blueprint_library = require("util.blueprint_library")
local description_codec = require("util.description_codec")
local cursor_blueprint_source = require("util.cursor_blueprint_source")
local tracker = require("split_tracker")

local M = {}

local DEFAULT_PLAN_NAME = "Untitled Plan"

-- Plans move between saves as blueprint books. That keeps transfer in the
-- player's normal workflow and avoids introducing a separate file format or
-- external persistence mechanism.

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

local function item_main_inventory_id()
  if defines and defines.inventory and defines.inventory.item_main then
    return defines.inventory.item_main
  end

  return 1
end

local function inventory_slot_limit(inventory)
  if not inventory then
    return 0
  end

  local ok, limit = pcall(function()
    return #inventory
  end)
  if ok and type(limit) == "number" then
    return limit
  end

  return 0
end

local function find_last_readable_stack(inventory)
  if not inventory then
    return nil
  end

  local limit = inventory_slot_limit(inventory)
  for index = limit, 1, -1 do
    local stack = inventory[index]
    if stack and stack.valid_for_read then
      return stack
    end
  end

  return nil
end

local function append_stack_to_inventory(inventory, item_name)
  if not inventory or not inventory.insert then
    return nil
  end

  if inventory.insert({name = item_name, count = 1}) ~= 1 then
    return nil
  end

  return find_last_readable_stack(inventory)
end

local function non_empty_string(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end

  return value
end

local function source_label(source)
  local label = non_empty_string(safe_index(source, "label"))
  if label then
    return label
  end
  return nil
end

local function source_blueprint_description(source)
  local description = safe_index(source, "blueprint_description")
  if type(description) ~= "string" then
    return nil
  end

  return description
end

local function source_entries(source)
  if not source or cursor_blueprint_source.source_type(source) ~= "blueprint-book" then
    return nil
  end

  -- Blueprint books can come from either runtime item stacks or library records.
  -- Normalize both shapes to a sorted slot list so import/export code can stay
  -- agnostic about where the book came from.
  local contents = safe_index(source, "contents")
  if type(contents) == "table" then
    local ordered = {}
    for index, entry in pairs(contents) do
      ordered[#ordered + 1] = {
        index = index,
        entry = entry
      }
    end
    table.sort(ordered, function(a, b)
      return a.index < b.index
    end)
    return ordered
  end

  local inventory = source.get_inventory and source.get_inventory(item_main_inventory_id()) or nil
  if not inventory then
    return nil
  end

  local ordered = {}
  local limit = 0
  local ok, length = pcall(function()
    return #inventory
  end)
  if ok and type(length) == "number" then
    limit = length
  end

  for index = 1, limit do
    ordered[#ordered + 1] = {
      index = index,
      entry = inventory[index]
    }
  end

  return ordered
end

local function resolve_import_source(player)
  local match = cursor_blueprint_source.find_cursor_blueprint_book(player)
  return match and match.source or nil
end

local function apply_active_plan(state, plan, source)
  state.splits = plan.splits or {}
  state.plan_source = source
  state.plan_id = plan.plan_id or state.plan_id
  state.plan_name = plan.plan_name or DEFAULT_PLAN_NAME
  state.current_split_index = 1
  state.editor_selection = {}

  tracker.init(state)

  if not state.plan_id then
    state.plan_id = "plan-" .. state.next_split_id
  end
end

local function parse_description(description)
  if type(description) ~= "string" or description == "" then
    return nil
  end

  return description_codec.import_from_description(description)
end

local function find_plan_metadata_from_item_stack(item_stack)
  if not (item_stack and cursor_blueprint_source.source_is_valid(item_stack) and cursor_blueprint_source.source_type(item_stack) == "blueprint-book") then
    return nil
  end

  local metadata = parse_description(source_blueprint_description(item_stack))
  if not metadata or metadata.format ~= "long-pole-plan" then
    return nil
  end

  metadata.plan_name = source_label(item_stack) or DEFAULT_PLAN_NAME
  return metadata
end

local function extract_blueprint_metadata(record, blueprint)
  if not (record and record.is_blueprint and record.get_blueprint_entity_count) then
    return blueprint
  end

  if record.get_blueprint_entity_count() < 1 then
    return blueprint
  end

  local extracted_fingerprint = blueprint_fingerprint.extract_blueprint_fingerprint(record, blueprint)
  blueprint.entity_count = extracted_fingerprint.entity_count
  blueprint.entity_summary = extracted_fingerprint.entity_summary
  blueprint.blueprint_fingerprint = blueprint.blueprint_fingerprint or extracted_fingerprint.blueprint_fingerprint
  return blueprint
end

local function configure_blueprint_link_carrier(stack)
  if not (stack and stack.set_blueprint_entities) then
    return true
  end

  -- Long Pole stores blueprint symlink metadata in blueprint_description. The
  -- placeholder entity only keeps Factorio treating this slot as a real
  -- blueprint so that the symlink metadata survives round-trips.
  stack.set_blueprint_entities({
    {
      entity_number = 1,
      name = "constant-combinator",
      position = {x = 0, y = 0}
    }
  })

  return true
end

local function decode_blueprint_reference(record)
  if not (record and cursor_blueprint_source.source_is_valid(record) and cursor_blueprint_source.source_type(record) == "blueprint") then
    return nil, "Split book contains an entry that is not a blueprint."
  end

  local decoded = parse_description(source_blueprint_description(record))
  if decoded and decoded.format ~= "long-pole-blueprint-link" then
    return nil, "Split book contains a blueprint with an unexpected description format."
  end

  if not decoded and record.get_blueprint_entity_count and record.get_blueprint_entity_count() < 1 then
    return nil, "Split book contains an empty blueprint without Long Pole link metadata."
  end

  -- Symlink metadata is authoritative when present. That keeps lightweight
  -- placeholder carriers usable even though their blueprint body is not the
  -- thing Long Pole actually cares about.
  local blueprint = decoded or {
    name = source_label(record) or "Unnamed Blueprint"
  }

  blueprint.name = source_label(record) or blueprint.name or blueprint.blueprint_name or "Unnamed Blueprint"
  blueprint.blueprint_name = blueprint.blueprint_name or blueprint.name

  if decoded then
    return blueprint, nil
  end

  return extract_blueprint_metadata(record, blueprint), nil
end

local function decode_split_from_book_item(book_item, split_index)
  if not (book_item and cursor_blueprint_source.source_is_valid(book_item) and cursor_blueprint_source.source_type(book_item) == "blueprint-book") then
    return nil, "Plan book contains an entry that is not a split book."
  end

  local description = parse_description(source_blueprint_description(book_item))
  if not description or description.format ~= "long-pole-split" then
    return nil, "Split book is missing Long Pole split metadata."
  end

  local split = {
    name = source_label(book_item) or ("Split %d"):format(split_index),
    surface = description.surface or "nauvis",
    items = description.items or {},
    blueprints = {},
    technologies = description.technologies or {},
    notes = description.notes or ""
  }

  local entries = source_entries(book_item)
  if not entries then
    return nil, "Split book did not expose an internal inventory."
  end

  for _, slot in ipairs(entries) do
    local entry = slot.entry
    if entry and cursor_blueprint_source.source_is_valid(entry) then
      local blueprint, error_message = decode_blueprint_reference(entry)
      if not blueprint then
        return nil, error_message
      end
      split.blueprints[#split.blueprints + 1] = blueprint
    end
  end

  return split
end

local function decode_plan_from_book_item(book_item)
  local metadata = find_plan_metadata_from_item_stack(book_item)
  if not metadata then
    return nil, "Held blueprint book does not contain a Long Pole plan."
  end

  local entries = source_entries(book_item)
  if not entries then
    return nil, "Held blueprint book did not expose an internal inventory."
  end

  local splits = {}
  for _, slot in ipairs(entries) do
    local entry = slot.entry
    if entry and cursor_blueprint_source.source_is_valid(entry) then
      local split, error_message = decode_split_from_book_item(entry, #splits + 1)
      if not split then
        return nil, error_message
      end
      splits[#splits + 1] = split
    end
  end

  return {
    plan_id = metadata.plan_id,
    plan_name = metadata.plan_name,
    splits = splits
  }, nil
end

local function build_plan_description(state)
  return description_codec.export_to_description({
    format = "long-pole-plan",
    plan_id = state.plan_id,
    visibility = "references-only",
    default_surface = (state.splits[1] and state.splits[1].surface) or "nauvis"
  })
end

local function build_split_description(split)
  return description_codec.export_to_description({
    format = "long-pole-split",
    surface = split.surface or "nauvis",
    items = split.items or {},
    technologies = split.technologies or {},
    notes = split.notes or ""
  })
end

local function build_blueprint_link_description(blueprint)
  return description_codec.export_to_description({
    format = "long-pole-blueprint-link",
    link_mode = blueprint.link_mode or "reference",
    library_root = blueprint.library_root or "player-blueprints",
    inside_books = blueprint.inside_books,
    source_book_label = blueprint.source_book_label,
    blueprint_name = blueprint.name,
    blueprint_slot = blueprint.blueprint_slot or blueprint.source_book_active_index,
    source_book_active_index = blueprint.source_book_active_index,
    entity_summary = blueprint.entity_summary,
    blueprint_fingerprint = blueprint.blueprint_fingerprint
  })
end

function M.create_empty_plan(state)
  local next_split_id = state.next_split_id or 1
  return {
    plan_id = "plan-" .. next_split_id,
    plan_name = DEFAULT_PLAN_NAME,
    splits = {}
  }
end

function M.create_new_plan(state)
  apply_active_plan(state, M.create_empty_plan(state), "new")
  return true
end

function M.has_active_plan(state)
  return state and state.splits and #state.splits > 0
end

function M.is_importable_plan_book(item_stack)
  return find_plan_metadata_from_item_stack(item_stack) ~= nil
end

function M.importable_plan_from_player(player)
  local source = resolve_import_source(player)
  if M.is_importable_plan_book(source) then
    return source
  end

  return nil
end

function M.decode_plan_from_item_stack(item_stack)
  return decode_plan_from_book_item(item_stack)
end

function M.import_plan_from_source(source, state)
  if not source then
    return false, "Hold a Long Pole blueprint book in the cursor to import it."
  end

  local plan, error_message = decode_plan_from_book_item(source)
  if not plan then
    return false, error_message
  end

  apply_active_plan(state, plan, "imported")
  return true, nil
end

function M.import_plan_from_cursor(player, state)
  local source = M.importable_plan_from_player(player)
  return M.import_plan_from_source(source, state)
end

function M.import_first_plan_from_blueprint_library(player, state, game_script)
  local match = blueprint_library.find_first_blueprint_book_matching(player, game_script, function(record)
    return M.is_importable_plan_book(record)
  end)
  if not match then
    return false, "No Long Pole plan book was found in the blueprint library."
  end

  return M.import_plan_from_source(match.record, state)
end

function M.can_export_to_cursor(cursor_stack, state)
  if not cursor_stack.valid_for_read then
    return true
  end

  -- Overwriting is only safe when the cursor already holds this same plan book.
  -- That protects arbitrary player blueprints from being replaced by accident.
  local metadata = find_plan_metadata_from_item_stack(cursor_stack)
  if not metadata then
    return false
  end

  return metadata.plan_id == state.plan_id
end

function M.export_plan_to_cursor(player, state)
  if not M.has_active_plan(state) then
    return false, "There is no active plan to save yet."
  end

  local cursor_stack = player.cursor_stack
  if not M.can_export_to_cursor(cursor_stack, state) then
    return false, "Clear the cursor before saving so the new plan book can be placed there."
  end

  if cursor_stack.valid_for_read then
    cursor_stack.clear()
  end

  if not cursor_stack.set_stack({name = "blueprint-book"}) then
    return false, "Could not create a blueprint book in the cursor."
  end

  local plan_description, plan_error = build_plan_description(state)
  if not plan_description then
    cursor_stack.clear()
    return false, plan_error or "Could not encode the plan description."
  end

  cursor_stack.label = state.plan_name or DEFAULT_PLAN_NAME
  cursor_stack.blueprint_description = plan_description

  local inventory = cursor_stack.get_inventory(item_main_inventory_id())
  if not inventory then
    cursor_stack.clear()
    return false, "The exported blueprint book did not expose an internal inventory."
  end

  for split_index, split in ipairs(state.splits or {}) do
    local split_stack = append_stack_to_inventory(inventory, "blueprint-book")
    if not split_stack then
      cursor_stack.clear()
      return false, "This plan has more splits than fit in one blueprint book."
    end
    if not split_stack.set_stack({name = "blueprint-book"}) then
      cursor_stack.clear()
      return false, "Could not create a split book in the exported plan."
    end

    local split_description, split_error = build_split_description(split)
    if not split_description then
      cursor_stack.clear()
      return false, split_error or "Could not encode split metadata."
    end

    split_stack.label = split.name or ("Split %d"):format(split_index)
    split_stack.blueprint_description = split_description

    local split_inventory = split_stack.get_inventory(item_main_inventory_id())
    if not split_inventory then
      cursor_stack.clear()
      return false, "An exported split book did not expose an internal inventory."
    end

    for _, blueprint in ipairs(split.blueprints or {}) do
      local blueprint_stack = append_stack_to_inventory(split_inventory, "blueprint")
      if not blueprint_stack then
        cursor_stack.clear()
        return false, ("Split '%s' has more linked blueprints than fit in one blueprint book."):format(split.name or ("Split %d"):format(split_index))
      end
      if not blueprint_stack.set_stack({name = "blueprint"}) then
        cursor_stack.clear()
        return false, "Could not create a linked blueprint entry in the exported split book."
      end
      configure_blueprint_link_carrier(blueprint_stack)

      local link_description, link_error = build_blueprint_link_description(blueprint)
      if not link_description then
        cursor_stack.clear()
        return false, link_error or "Could not encode linked blueprint metadata."
      end

      blueprint_stack.label = blueprint.name or "Unnamed Blueprint"
      blueprint_stack.blueprint_description = link_description
    end
  end

  cursor_stack.active_index = 1
  return true, nil
end

function M.entry_button_spec(player, state)
  if M.importable_plan_from_player(player) then
    return {
      caption = "↓",
      tooltip = "Import the held Long Pole plan book and replace the current plan.",
      is_compact = true,
      mode = "import"
    }
  end

  if M.has_active_plan(state) then
    return {
      caption = "✎",
      tooltip = "Edit the active plan.",
      is_compact = true,
      mode = "edit"
    }
  end

  return {
    caption = "✎",
    tooltip = "Create a new empty plan and open the editor.",
    is_compact = true,
    mode = "new"
  }
end

return M
