local progress_tracker_store = require("progress_tracker_store")
local build_requirements = require("build_requirements")

local M = {}

-- Split tracker owns the editable plan state plus a few runtime-only helpers
-- like requirement caches and current-split timing. The UI talks to this module
-- so persistence and progress logic do not have to know about widget details.

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

  -- Requirement trees are pure functions of split content. Bumping a revision
  -- number gives us cheap invalidation without diffing every nested table edit.
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
  -- Keep imports from older drafts readable by normalizing legacy field names
  -- and always materializing the collections the editor expects.
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
  state.entity_events = state.entity_events or {}
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

  -- Current progress and per-player editor selection are logical properties of
  -- a split, not of its transient list position, so move those pointers with it.
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

function M.on_entity_changed(state, event)
  local entity = event.entity or event.created_entity
  state.entity_events[#state.entity_events + 1] = {
    tick = event.tick,
    unit_number = entity and entity.unit_number or nil,
    name = entity and entity.name or nil
  }
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

local function icon_group(entries, options)
  if not entries or #entries == 0 then
    return nil
  end

  return {
    entries = entries,
    tone = options and options.tone or "normal",
    sort_mode = options and options.sort_mode or "progress",
    kind = options and options.kind or "requirements"
  }
end

function M.get_split_status(state, force_name)
  clamp_current_index(state)

  local statuses = {
    previous = nil,
    current = nil,
    upcoming = {}
  }

  local current_index = state.current_split_index
  local current_split = state.splits[current_index]
  local current_snapshot = nil
  local current_missing = {}
  local current_error_message = nil
  local current_reserved_pools = nil
  local current_stock_debt = {}
  local current_placement_progress = {}
  local current_research_progress = {}
  local next_split_readiness = {}

  if current_split then
    current_snapshot = force_name and M.get_split_progress_snapshot(state, current_index, force_name) or nil
    current_missing, current_error_message, current_reserved_pools = build_requirements.summarize_missing_requirements(
      current_split,
      current_snapshot,
      {
        root_requirements = cached_root_requirements(state, current_split, "all-requirements")
      }
    )
    current_stock_debt = build_requirements.summarize_direct_requirement_progress(current_split, current_snapshot, {
      root_requirements = cached_root_requirements(state, current_split, "stock-debt", {
        include_technologies = false
      }),
      include_technologies = false
    })
    current_placement_progress = build_requirements.summarize_direct_requirement_progress(current_split, current_snapshot, {
      root_requirements = cached_root_requirements(state, current_split, "placement-progress", {
        include_items = false,
        include_technologies = false,
        blueprint_satisfaction_mode = "placed_only"
      }),
      include_items = false,
      include_technologies = false,
      blueprint_satisfaction_mode = "placed_only"
    })
    current_research_progress = build_requirements.summarize_missing_requirements(current_split, current_snapshot, {
      root_requirements = cached_root_requirements(state, current_split, "research-progress", {
        include_blueprints = false,
        include_items = false
      }),
      include_blueprints = false,
      include_items = false
    })
  end

  local next_split = state.splits[current_index + 1]
  if next_split then
    local next_snapshot = nil
    local next_initial_pools = nil

    if force_name and current_split and next_split.surface == current_split.surface then
      next_snapshot = current_snapshot
      next_initial_pools = current_reserved_pools
    elseif force_name then
      next_snapshot = M.get_split_progress_snapshot(state, current_index + 1, force_name)
    end

    next_split_readiness = build_requirements.summarize_direct_requirement_progress(next_split, next_snapshot, {
      root_requirements = cached_root_requirements(state, next_split, "next-readiness", {
        include_technologies = false,
        blueprint_satisfaction_mode = "loose_only"
      }),
      include_technologies = false,
      blueprint_satisfaction_mode = "loose_only",
      initial_pools = next_initial_pools
    })
  end

  -- Reserve current-split claims before computing next-split readiness so the
  -- viewer answers "what is actually left over if I advance right now?"
  for index, split in ipairs(state.splits) do
    local status = {
      index = index,
      name = split.name,
      missing = index == current_index and current_missing or {},
      missing_error = index == current_index and current_error_message or nil,
      is_current = index == current_index,
      is_ready_to_complete = index == current_index and current_error_message == nil and #current_missing == 0,
      completed_elapsed_ticks = split.completed_elapsed_ticks,
      icon_groups = {}
    }

    if index == current_index - 1 then
      local group = icon_group(current_stock_debt, {
        tone = "alert",
        sort_mode = "progress",
        kind = "carry-over-stock"
      })
      if group then
        status.icon_groups[#status.icon_groups + 1] = group
      end
      statuses.previous = status
    elseif index == current_index then
      local placement_group = icon_group(current_placement_progress, {
        tone = "normal",
        sort_mode = "remaining",
        kind = "placement-progress"
      })
      local research_group = icon_group(current_research_progress, {
        tone = "normal",
        sort_mode = "progress",
        kind = "research-production"
      })
      if placement_group then
        status.icon_groups[#status.icon_groups + 1] = placement_group
      end
      if research_group then
        status.icon_groups[#status.icon_groups + 1] = research_group
      end
      statuses.current = status
    elseif index == current_index + 1 then
      local group = icon_group(next_split_readiness, {
        tone = "normal",
        sort_mode = "progress",
        kind = "next-split-readiness"
      })
      if group then
        status.icon_groups[#status.icon_groups + 1] = group
      end
      statuses.upcoming[#statuses.upcoming + 1] = status
    elseif index > current_index then
      statuses.upcoming[#statuses.upcoming + 1] = status
    end
  end

  return statuses
end

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

return M
