local tracker = require("split_tracker")

local M = {}

local PLAN_FORMAT = "long-pole-plan"
local SCHEMA_VERSION = 1
local PLAN_CHUNK_TAG = "long-pole.plan_chunk"
local PLAN_BOOK_TAG = "long-pole.plan_book"
local DEFAULT_PLAN_NAME = "Untitled Plan"
local CHUNK_SIZE = 12000

local function shallow_copy_entries(entries)
  local copied = {}
  for index, entry in ipairs(entries or {}) do
    local entry_copy = {}
    for key, value in pairs(entry) do
      entry_copy[key] = value
    end
    copied[index] = entry_copy
  end
  return copied
end

local function normalize_split_for_payload(split)
  return {
    id = split.id,
    name = split.name,
    items = shallow_copy_entries(split.items),
    blueprints = shallow_copy_entries(split.blueprints),
    technologies = shallow_copy_entries(split.technologies),
    notes = split.notes or ""
  }
end

local function checksum_string(value)
  local hash = 5381
  for index = 1, #value do
    hash = (hash * 33 + value:byte(index)) % 2147483647
  end
  return tostring(hash)
end

local function split_encoded_payload(encoded_payload)
  local chunks = {}
  for index = 1, #encoded_payload, CHUNK_SIZE do
    chunks[#chunks + 1] = encoded_payload:sub(index, index + CHUNK_SIZE - 1)
  end

  if #chunks == 0 then
    chunks[1] = ""
  end

  return chunks
end

local function build_plan_payload(state)
  local splits = {}
  for index, split in ipairs(state.splits) do
    splits[index] = normalize_split_for_payload(split)
  end

  return {
    format = PLAN_FORMAT,
    schema_version = SCHEMA_VERSION,
    plan_id = state.plan_id,
    plan_name = state.plan_name or DEFAULT_PLAN_NAME,
    splits = splits
  }
end

local function build_book_metadata(state)
  return {
    format = PLAN_FORMAT,
    schema_version = SCHEMA_VERSION,
    plan_id = state.plan_id,
    plan_name = state.plan_name or DEFAULT_PLAN_NAME
  }
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

local function find_chunk_record(record)
  if not (record and record.valid_for_read and record.is_blueprint) then
    return nil
  end

  if record.get_blueprint_entity_count() < 1 then
    return nil
  end

  return record.get_blueprint_entity_tag(1, PLAN_CHUNK_TAG)
end

local function decode_plan_from_book_item(book_item)
  if not (book_item and book_item.valid_for_read and book_item.is_blueprint_book) then
    return nil, "No blueprint book found."
  end

  local inventory = book_item.get_inventory(defines.inventory.item_main)
  if not inventory then
    return nil, "Held blueprint book did not expose an internal inventory."
  end

  local chunks = {}
  for index = 1, #inventory do
    local chunk = find_chunk_record(inventory[index])
    if chunk then
      chunks[#chunks + 1] = chunk
    end
  end

  if #chunks == 0 then
    return nil, "Held blueprint book does not contain a Long Pole plan."
  end

  table.sort(chunks, function(a, b)
    return (a.chunk_index or 0) < (b.chunk_index or 0)
  end)

  local expected_chunk_count = chunks[1].chunk_count
  local encoded_parts = {}
  for index, chunk in ipairs(chunks) do
    if chunk.format ~= PLAN_FORMAT then
      return nil, "Held blueprint book is not a Long Pole plan."
    end

    if chunk.schema_version ~= SCHEMA_VERSION then
      return nil, "Plan schema version is not supported by this mod version."
    end

    if chunk.chunk_count ~= expected_chunk_count or chunk.chunk_index ~= index then
      return nil, "Plan data chunks are incomplete or out of order."
    end

    encoded_parts[index] = chunk.payload or ""
  end

  local encoded_payload = table.concat(encoded_parts)
  if checksum_string(encoded_payload) ~= chunks[1].checksum then
    return nil, "Plan checksum did not match; the blueprint book may be corrupted."
  end

  local decoded_payload = helpers.decode_string(encoded_payload)
  if not decoded_payload then
    return nil, "Plan payload could not be decoded."
  end

  local plan = helpers.json_to_table(decoded_payload)
  if not plan or plan.format ~= PLAN_FORMAT then
    return nil, "Plan payload is invalid."
  end

  return plan, nil
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
  if not (item_stack and item_stack.valid_for_read and item_stack.is_blueprint_book) then
    return false
  end

  local inventory = item_stack.get_inventory(defines.inventory.item_main)
  if not inventory then
    return false
  end

  for index = 1, #inventory do
    local stack = inventory[index]
    if stack.valid_for_read and stack.is_blueprint and stack.get_blueprint_entity_count() >= 1 then
      if stack.get_blueprint_entity_tag(1, PLAN_CHUNK_TAG) then
        return true
      end
    end
  end

  return false
end

function M.decode_plan_from_item_stack(item_stack)
  return decode_plan_from_book_item(item_stack)
end

function M.import_plan_from_cursor(player, state)
  local cursor_stack = player.cursor_stack
  if not M.is_importable_plan_book(cursor_stack) then
    return false, "Hold a Long Pole blueprint book in the cursor to import it."
  end

  local plan, error_message = decode_plan_from_book_item(cursor_stack)
  if not plan then
    return false, error_message
  end

  apply_active_plan(state, plan, "imported")
  return true, nil
end

function M.can_export_to_cursor(cursor_stack, state)
  if not cursor_stack.valid_for_read then
    return true
  end

  local metadata = cursor_stack.get_tag(PLAN_BOOK_TAG)
  if not metadata then
    return false
  end

  return metadata.format == PLAN_FORMAT and metadata.plan_id == state.plan_id
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

  cursor_stack.label = state.plan_name or DEFAULT_PLAN_NAME
  cursor_stack.blueprint_description = "Portable Long Pole run plan"
  cursor_stack.set_tag(PLAN_BOOK_TAG, build_book_metadata(state))

  local payload_json = helpers.table_to_json(build_plan_payload(state))
  local encoded_payload = helpers.encode_string(payload_json)
  if not encoded_payload then
    cursor_stack.clear()
    return false, "Could not encode the plan payload."
  end

  local chunks = split_encoded_payload(encoded_payload)
  local checksum = checksum_string(encoded_payload)
  local inventory = cursor_stack.get_inventory(defines.inventory.item_main)
  if not inventory then
    cursor_stack.clear()
    return false, "The exported blueprint book did not expose an internal inventory."
  end

  for chunk_index, payload_chunk in ipairs(chunks) do
    local stack = inventory[chunk_index]
    if not stack.set_stack({name = "blueprint"}) then
      cursor_stack.clear()
      return false, "Could not create a carrier blueprint in the exported book."
    end

    stack.label = ("Plan Chunk %d/%d"):format(chunk_index, #chunks)
    stack.blueprint_description = "Long Pole plan carrier"
    stack.set_blueprint_entities({
      {
        entity_number = 1,
        name = "constant-combinator",
        position = {x = 0, y = 0}
      }
    })
    stack.set_blueprint_entity_tag(1, PLAN_CHUNK_TAG, {
      format = PLAN_FORMAT,
      schema_version = SCHEMA_VERSION,
      plan_id = state.plan_id,
      plan_name = state.plan_name or DEFAULT_PLAN_NAME,
      chunk_index = chunk_index,
      chunk_count = #chunks,
      checksum = checksum,
      payload = payload_chunk
    })
  end

  cursor_stack.active_index = 1
  return true, nil
end

function M.entry_button_spec(player, state)
  if M.has_active_plan(state) then
    return {
      caption = "✎",
      tooltip = "Edit the active plan.",
      is_compact = true,
      mode = "edit"
    }
  end

  if M.is_importable_plan_book(player.cursor_stack) then
    return {
      caption = "Import Plan",
      tooltip = "Import the held Long Pole plan book.",
      is_compact = false,
      mode = "import"
    }
  end

  return {
    caption = "New Plan",
    tooltip = "Create a new empty plan and open the editor.",
    is_compact = false,
    mode = "new"
  }
end

return M
