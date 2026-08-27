local progress_tracker_store = require("progress_tracker_store")
local build_requirements = require("build_requirements")
local split_status = require("split_status")

local M = {}

local function ensure_requirement_cache(state)
  state.split_requirement_cache = state.split_requirement_cache or {
    by_split_id = {}
  }
  return state.split_requirement_cache
end

local function invalidate_split_requirement_cache(state, split)
  if not split then
    return
  end

  split.requirement_revision = (split.requirement_revision or 0) + 1
  ensure_requirement_cache(state).by_split_id[split.id] = nil
end

local function cached_root_requirements(state, split, cache_key, options)
  if not (split and split.id and cache_key) then
    return build_requirements.build_root_requirements(split, options or {})
  end

  local cache_root = ensure_requirement_cache(state).by_split_id
  local split_cache = cache_root[split.id]
  if not split_cache then
    split_cache = {}
    cache_root[split.id] = split_cache
  end

  local revision = split.requirement_revision or 0
  local cached = split_cache[cache_key]
  if cached and cached.revision == revision then
    return cached.entries
  end

  local entries = build_requirements.build_root_requirements(split, options or {})
  split_cache[cache_key] = {
    revision = revision,
    entries = entries
  }
  return entries
end

local function ensure_next_split_id(state)
  state.next_split_id = state.next_split_id or 1
  return state.next_split_id
end

local function take_next_split_id(state)
  local next_id = ensure_next_split_id(state)
  state.next_split_id = next_id + 1
  return next_id
end

local function copy_entries(entries)
  local copied = {}
  for index, entry in ipairs(entries or {}) do
    local item_copy = {}
    for key, value in pairs(entry) do
      item_copy[key] = value
    end
    copied[index] = item_copy
  end
  return copied
end

local function normalize_item_entry(item)
  local entry = copy_entries({item or {count = 1}})[1]
  entry.count = math.max(1, math.floor(tonumber(entry.count) or 1))
  if entry.name == "" then
    entry.name = nil
  end
  return entry
end

local function normalize_technology_entry(technology)
  local entry = copy_entries({technology or {}})[1]
  local name = (entry.name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  entry.name = name ~= "" and name or nil
  return entry
end

local function normalize_technology_entries(technologies)
  local normalized = {}
  local seen = {}

  for _, technology in ipairs(technologies or {}) do
    local entry = normalize_technology_entry(technology)
    if entry.name and not seen[entry.name] then
      seen[entry.name] = true
      normalized[#normalized + 1] = entry
    end
  end

  return normalized
end

local function normalize_split(split, fallback_name)
  split.name = split.name or fallback_name or "Untitled Split"
  split.items = copy_entries(split.items)
  split.blueprints = copy_entries(split.blueprints)
  split.technologies = copy_entries(split.technologies)
  split.notes = split.notes or ""
  split.completed_elapsed_ticks = split.completed_elapsed_ticks or nil
  split.surface = split.surface or split.planet or "nauvis"
  split.requirement_revision = split.requirement_revision or 0
  split.planet = nil
  return split
end

local function clamp_current_index(state)
  if #state.splits == 0 then
    state.current_split_index = 1
    return
  end

  if state.current_split_index < 1 then
    state.current_split_index = 1
  elseif state.current_split_index > (#state.splits + 1) then
    state.current_split_index = #state.splits + 1
  end
end

function M.init(state)
  state.inventory = state.inventory or {}
  state.splits = state.splits or {}
  state.current_split_index = state.current_split_index or 1
  state.current_split_started_tick = state.current_split_started_tick
  state.editor_selection = state.editor_selection or {}
  state.split_requirement_cache = {
    by_split_id = {}
  }
  progress_tracker_store.init(state)
  ensure_next_split_id(state)

  for index, split in ipairs(state.splits) do
    state.splits[index] = normalize_split(split, ("Split %d"):format(index))
    if not state.splits[index].id then
      state.splits[index].id = take_next_split_id(state)
    elseif state.splits[index].id >= state.next_split_id then
      state.next_split_id = state.splits[index].id + 1
    end
  end

  clamp_current_index(state)
end

function M.ensure_current_split_started(state, current_tick)
  clamp_current_index(state)
  if #state.splits == 0 or state.current_split_index > #state.splits then
    state.current_split_started_tick = nil
    return nil
  end

  if state.current_split_started_tick == nil then
    state.current_split_started_tick = current_tick or 0
  end

  return state.current_split_started_tick
end

function M.current_split_elapsed_ticks(state, current_tick)
  local started_tick = M.ensure_current_split_started(state, current_tick)
  if started_tick == nil then
    return nil
  end

  local resolved_tick = current_tick or started_tick
  return math.max(0, resolved_tick - started_tick)
end

function M.create_split(state, name)
  local split = normalize_split({
    name = name,
    items = {},
    blueprints = {},
    technologies = {},
    requirement_revision = 0
  }, name)
  split.id = take_next_split_id(state)
  return split
end

function M.add_split(state, name)
  local split = M.create_split(state, name or ("Split %d"):format(#state.splits + 1))
  table.insert(state.splits, split)
  clamp_current_index(state)
  return #state.splits, split
end

function M.get_split(state, index)
  return state.splits[index]
end

function M.get_selected_split_index(state, player_index)
  local selected = state.editor_selection[player_index]
  if selected and state.splits[selected] then
    return selected
  end
  if #state.splits == 0 then
    return state.current_split_index
  end
  return math.min(state.current_split_index, #state.splits)
end

function M.find_split_index_by_id(state, split_id)
  for index, split in ipairs(state.splits) do
    if split.id == split_id then
      return index
    end
  end

  return nil
end

function M.get_split_by_id(state, split_id)
  local split_index = M.find_split_index_by_id(state, split_id)
  if split_index then
    return state.splits[split_index], split_index
  end

  return nil, nil
end

function M.set_selected_split_index(state, player_index, split_index)
  if state.splits[split_index] then
    state.editor_selection[player_index] = split_index
    return true
  end
  return false
end

function M.rename_split(state, split_index, name)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  local trimmed = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  split.name = trimmed ~= "" and trimmed or ("Split %d"):format(split_index)
  return true
end

function M.rename_split_by_id(state, split_id, name)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.rename_split(state, split_index, name)
end

function M.set_split_notes(state, split_index, notes)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  split.notes = notes or ""
  return true
end

function M.set_split_notes_by_id(state, split_id, notes)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_notes(state, split_index, notes)
end

function M.set_split_blueprints(state, split_index, blueprints)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  split.blueprints = copy_entries(blueprints)
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_blueprints_by_id(state, split_id, blueprints)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_blueprints(state, split_index, blueprints)
end

function M.add_split_blueprint_by_id(state, split_id, blueprint)
  local split = M.get_split_by_id(state, split_id)
  if not split or not blueprint then
    return false
  end

  split.blueprints[#split.blueprints + 1] = copy_entries({blueprint})[1]
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.replace_split_blueprint_by_id(state, split_id, blueprint_index, blueprint)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.blueprints[blueprint_index] or not blueprint then
    return false
  end

  split.blueprints[blueprint_index] = copy_entries({blueprint})[1]
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.remove_split_blueprint_by_id(state, split_id, blueprint_index)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.blueprints[blueprint_index] then
    return false
  end

  table.remove(split.blueprints, blueprint_index)
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_items(state, split_index, items)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  split.items = copy_entries(items)
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_items_by_id(state, split_id, items)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_items(state, split_index, items)
end

function M.add_split_item_by_id(state, split_id, item)
  local split = M.get_split_by_id(state, split_id)
  if not split then
    return false
  end

  split.items[#split.items + 1] = normalize_item_entry(item)
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.replace_split_item_by_id(state, split_id, item_index, item)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.items[item_index] then
    return false
  end

  if not item or not item.name or item.name == "" then
    table.remove(split.items, item_index)
    invalidate_split_requirement_cache(state, split)
    return true
  end

  split.items[item_index] = normalize_item_entry(item)
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_item_name_by_id(state, split_id, item_index, item_name)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.items[item_index] then
    return false
  end

  if not item_name or item_name == "" then
    table.remove(split.items, item_index)
    invalidate_split_requirement_cache(state, split)
    return true
  end

  split.items[item_index].name = item_name
  split.items[item_index].count = math.max(1, math.floor(tonumber(split.items[item_index].count) or 1))
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_item_count_by_id(state, split_id, item_index, count)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.items[item_index] then
    return false
  end

  split.items[item_index].count = math.max(1, math.floor(tonumber(count) or 1))
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.remove_split_item_by_id(state, split_id, item_index)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.items[item_index] then
    return false
  end

  table.remove(split.items, item_index)
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_technologies(state, split_index, technologies)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  split.technologies = normalize_technology_entries(technologies)
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_technologies_by_id(state, split_id, technologies)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_technologies(state, split_index, technologies)
end

function M.add_split_technology_by_id(state, split_id, technology)
  local split = M.get_split_by_id(state, split_id)
  if not split then
    return false
  end

  local entry = normalize_technology_entry(technology)
  if not entry.name then
    return false
  end

  for _, existing in ipairs(split.technologies) do
    if existing.name == entry.name then
      return false
    end
  end

  split.technologies[#split.technologies + 1] = entry
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.remove_split_technology_by_id(state, split_id, technology_index)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.technologies[technology_index] then
    return false
  end

  table.remove(split.technologies, technology_index)
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_surface(state, split_index, surface_name)
  local split = state.splits[split_index]
  if not split or not surface_name or surface_name == "" then
    return false
  end

  split.surface = surface_name
  invalidate_split_requirement_cache(state, split)
  return true
end

function M.set_split_surface_by_id(state, split_id, surface_name)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_surface(state, split_index, surface_name)
end

function M.move_split(state, from_index, to_index)
  if from_index == to_index then
    return false
  end

  if not state.splits[from_index] or not state.splits[to_index] then
    return false
  end

  local split = table.remove(state.splits, from_index)
  table.insert(state.splits, to_index, split)

  if state.current_split_index == from_index then
    state.current_split_index = to_index
  elseif from_index < state.current_split_index and to_index >= state.current_split_index then
    state.current_split_index = state.current_split_index - 1
  elseif from_index > state.current_split_index and to_index <= state.current_split_index then
    state.current_split_index = state.current_split_index + 1
  end

  for player_index, selected_index in pairs(state.editor_selection) do
    if selected_index == from_index then
      state.editor_selection[player_index] = to_index
    elseif from_index < selected_index and to_index >= selected_index then
      state.editor_selection[player_index] = selected_index - 1
    elseif from_index > selected_index and to_index <= selected_index then
      state.editor_selection[player_index] = selected_index + 1
    end
  end

  clamp_current_index(state)
  return true
end

function M.remove_split(state, split_index)
  local removed_split = state.splits[split_index]
  if not removed_split then
    return false
  end

  table.remove(state.splits, split_index)
  ensure_requirement_cache(state).by_split_id[removed_split.id] = nil

  local split_count = #state.splits

  if state.current_split_index == split_index then
    if split_count == 0 then
      state.current_split_index = 1
      state.current_split_started_tick = nil
    elseif split_index > split_count then
      state.current_split_index = split_count
    end
  elseif state.current_split_index > split_index then
    state.current_split_index = state.current_split_index - 1
  end

  for player_index, selected_index in pairs(state.editor_selection) do
    if selected_index > split_index then
      state.editor_selection[player_index] = selected_index - 1
    elseif split_count == 0 then
      state.editor_selection[player_index] = nil
    elseif selected_index > split_count then
      state.editor_selection[player_index] = split_count
    end
  end

  clamp_current_index(state)
  return true
end

function M.remove_split_by_id(state, split_id)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.remove_split(state, split_index)
end

function M.get_split_progress_snapshot(state, split_index, force_name)
  local split = state.splits[split_index]
  if not split then
    return {
      force_name = force_name,
      surface_name = nil,
      entries = {},
      uncertainty = {}
    }
  end

  return progress_tracker_store.get_surface_snapshot(state, force_name, split.surface, split.id)
end

function M.get_current_split_progress_snapshot(state, force_name)
  return M.get_split_progress_snapshot(state, state.current_split_index, force_name)
end

function M.get_split_status(state, force_name)
  clamp_current_index(state)
  return split_status.build(state, force_name, {
    get_split_progress_snapshot = M.get_split_progress_snapshot,
    cached_root_requirements = function(status_state, split, cache_key, options)
      return cached_root_requirements(status_state, split, cache_key, options)
    end
  })
end

-- PRODUCT.md §6: the player may move forward or back at any time, including
-- when this split is incomplete. Do not gate navigation on predicted completion.
function M.advance_split(state, current_tick)
  clamp_current_index(state)
  local current_index = state.current_split_index
  local current_split = state.splits[current_index]
  if not current_split then
    return false
  end

  local finished_tick = current_tick or state.current_split_started_tick or 0
  current_split.completed_elapsed_ticks = M.current_split_elapsed_ticks(state, finished_tick) or 0

  if current_index < #state.splits then
    state.current_split_index = current_index + 1
    state.current_split_started_tick = current_tick or nil
    return true
  end

  state.current_split_index = #state.splits + 1
  state.current_split_started_tick = nil
  return true
end

function M.rewind_split(state, current_tick)
  clamp_current_index(state)
  if state.current_split_index <= 1 then
    return false
  end

  local current_split = state.splits[state.current_split_index]
  if current_split then
    current_split.completed_elapsed_ticks = nil
  end

  state.current_split_index = state.current_split_index - 1
  local previous_split = state.splits[state.current_split_index]
  if previous_split then
    previous_split.completed_elapsed_ticks = nil
  end
  state.current_split_started_tick = current_tick or 0
  return true
end

return M
