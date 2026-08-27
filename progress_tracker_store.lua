-- Loose-stock ledger. Heuristic: produced/mined/harvested/started-with minus
-- placed/consumed/spoiled/destroyed. Placement is bonus progress, not the
-- source of truth (PRODUCT.md §11, §14).
local M = {}

local STORAGE_VERSION = 2
local DEFAULT_FORCE_NAME = "player"

local function normalize_force_name(force_name)
  if type(force_name) ~= "string" or force_name == "" then
    return DEFAULT_FORCE_NAME
  end
  return force_name
end

local function normalize_surface_name(surface_name)
  if type(surface_name) ~= "string" or surface_name == "" then
    return nil
  end
  return surface_name
end

local function normalize_item_name(item_name)
  if type(item_name) ~= "string" or item_name == "" then
    return nil
  end
  return item_name
end

local function normalize_non_negative_count(value)
  return math.max(0, math.floor(tonumber(value) or 0))
end

local function normalize_delta(value)
  local number = tonumber(value)
  if not number then
    return nil
  end
  return math.floor(number)
end

local function copy_item_entry(entry)
  return {
    item_name = entry.item_name,
    loose_stock = entry.loose_stock,
    placed_count = entry.placed_count,
    current_split_claim = entry.current_split_claim,
    produced_total = entry.produced_total,
    consumed_total = entry.consumed_total
  }
end

local function ensure_root(state)
  state.progress_tracker = state.progress_tracker or {}
  local root = state.progress_tracker
  root.storage_version = STORAGE_VERSION
  root.forces = root.forces or {}
  root.placed_entity_index = root.placed_entity_index or {}
  return root
end

local function ensure_force(root, force_name)
  local normalized_force_name = normalize_force_name(force_name)
  local force = root.forces[normalized_force_name]
  if force then
    force.surfaces = force.surfaces or {}
    return force
  end

  force = {
    surfaces = {}
  }
  root.forces[normalized_force_name] = force
  return force
end

local function ensure_surface(root, force_name, surface_name)
  local normalized_surface_name = normalize_surface_name(surface_name)
  if not normalized_surface_name then
    return nil
  end

  local force = ensure_force(root, force_name)
  local surface = force.surfaces[normalized_surface_name]
  if surface then
    surface.loose_stock = surface.loose_stock or {}
    surface.placed_counts = surface.placed_counts or {}
    surface.placed_entities = surface.placed_entities or {}
    surface.placed_counts_by_split_id = surface.placed_counts_by_split_id or {}
    surface.production_totals = surface.production_totals or {}
    surface.production_input_exclusions = surface.production_input_exclusions or {}
    surface.uncertainty = surface.uncertainty or {}
    return surface
  end

  surface = {
    loose_stock = {},
    placed_counts = {},
    placed_entities = {},
    placed_counts_by_split_id = {},
    production_totals = {},
    production_input_exclusions = {},
    uncertainty = {}
  }
  force.surfaces[normalized_surface_name] = surface
  return surface
end

local function remove_zero_entry(entries, item_name)
  if entries[item_name] == 0 then
    entries[item_name] = nil
  end
end

local function change_placed_count(surface, item_name, delta)
  local current = surface.placed_counts[item_name] or 0
  local updated = math.max(0, current + delta)
  if updated == current then
    return updated
  end
  surface.placed_counts[item_name] = updated
  remove_zero_entry(surface.placed_counts, item_name)
  return updated
end

local function change_loose_stock(surface, item_name, delta)
  local current = surface.loose_stock[item_name] or 0
  local updated = math.max(0, current + delta)
  if updated == current then
    return updated
  end
  surface.loose_stock[item_name] = updated
  remove_zero_entry(surface.loose_stock, item_name)
  return updated
end

local function change_non_negative_count(entries, item_name, delta)
  local current = entries[item_name] or 0
  local updated = math.max(0, current + delta)
  entries[item_name] = updated
  remove_zero_entry(entries, item_name)
  return updated
end

local function ensure_production_total(surface, item_name)
  local entry = surface.production_totals[item_name]
  if entry then
    entry.produced_total = entry.produced_total or 0
    entry.consumed_total = entry.consumed_total or 0
    entry.last_input_count = entry.last_input_count or 0
    entry.last_output_count = entry.last_output_count or 0
    return entry
  end

  entry = {
    produced_total = 0,
    consumed_total = 0,
    last_input_count = 0,
    last_output_count = 0
  }
  surface.production_totals[item_name] = entry
  return entry
end

local function ensure_split_counts(surface, split_id)
  if split_id == nil then
    return nil
  end

  local counts = surface.placed_counts_by_split_id[split_id]
  if counts then
    return counts
  end

  counts = {}
  surface.placed_counts_by_split_id[split_id] = counts
  return counts
end

local function change_split_claim_count(surface, split_id, item_name, delta)
  if split_id == nil then
    return 0
  end

  local counts = ensure_split_counts(surface, split_id)
  local current = counts[item_name] or 0
  local updated = math.max(0, current + delta)
  if updated == current then
    return updated
  end

  counts[item_name] = updated
  remove_zero_entry(counts, item_name)
  if next(counts) == nil then
    surface.placed_counts_by_split_id[split_id] = nil
  end
  return updated
end

local function build_snapshot_entries(surface)
  local entry_by_item = {}

  for item_name, count in pairs(surface.loose_stock) do
    local produced_total = surface.production_totals[item_name] and surface.production_totals[item_name].produced_total or 0
    local consumed_total = surface.production_totals[item_name] and surface.production_totals[item_name].consumed_total or 0
    entry_by_item[item_name] = {
      item_name = item_name,
      loose_stock = count,
      placed_count = surface.placed_counts[item_name] or 0,
      current_split_claim = 0,
      produced_total = produced_total,
      consumed_total = consumed_total
    }
  end

  for item_name, count in pairs(surface.placed_counts) do
    if not entry_by_item[item_name] then
      local produced_total = surface.production_totals[item_name] and surface.production_totals[item_name].produced_total or 0
      local consumed_total = surface.production_totals[item_name] and surface.production_totals[item_name].consumed_total or 0
      entry_by_item[item_name] = {
        item_name = item_name,
        loose_stock = surface.loose_stock[item_name] or 0,
        placed_count = count,
        current_split_claim = 0,
        produced_total = produced_total,
        consumed_total = consumed_total
      }
    end
  end

  for item_name, totals in pairs(surface.production_totals) do
    if not entry_by_item[item_name] then
      entry_by_item[item_name] = {
        item_name = item_name,
        loose_stock = surface.loose_stock[item_name] or 0,
        placed_count = surface.placed_counts[item_name] or 0,
        current_split_claim = 0,
        produced_total = totals.produced_total or 0,
        consumed_total = totals.consumed_total or 0
      }
    else
      entry_by_item[item_name].produced_total = totals.produced_total or 0
      entry_by_item[item_name].consumed_total = totals.consumed_total or 0
    end
  end

  local entries = {}
  for _, entry in pairs(entry_by_item) do
    entries[#entries + 1] = entry
  end

  table.sort(entries, function(a, b)
    return a.item_name < b.item_name
  end)

  return entries
end

local function normalize_statistics_count(value)
  local number = tonumber(value) or 0
  if number <= 0 then
    return 0
  end
  return math.floor(number)
end

function M.init(state)
  ensure_root(state)
  return state.progress_tracker
end

function M.ensure_surface(state, force_name, surface_name)
  return ensure_surface(ensure_root(state), force_name, surface_name)
end

function M.set_loose_stock(state, force_name, surface_name, item_name, count)
  local normalized_item_name = normalize_item_name(item_name)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not (surface and normalized_item_name) then
    return false
  end

  local normalized_count = normalize_non_negative_count(count)
  local current = surface.loose_stock[normalized_item_name] or 0
  if normalized_count == current then
    return true
  end

  surface.loose_stock[normalized_item_name] = normalized_count
  remove_zero_entry(surface.loose_stock, normalized_item_name)
  return true
end

function M.adjust_loose_stock(state, force_name, surface_name, item_name, delta)
  local normalized_item_name = normalize_item_name(item_name)
  local normalized_delta = normalize_delta(delta)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not (surface and normalized_item_name and normalized_delta) then
    return false
  end

  change_loose_stock(surface, normalized_item_name, normalized_delta)
  return true
end

function M.get_loose_stock(state, force_name, surface_name, item_name)
  local normalized_item_name = normalize_item_name(item_name)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not (surface and normalized_item_name) then
    return 0
  end

  return surface.loose_stock[normalized_item_name] or 0
end

function M.upsert_placed_entity(state, entity)
  local unit_number = entity and entity.unit_number
  local force_name = normalize_force_name(entity and entity.force_name)
  local surface_name = normalize_surface_name(entity and entity.surface_name)
  local item_name = normalize_item_name(entity and entity.item_name)
  if unit_number == nil or not surface_name or not item_name then
    return false
  end

  local root = ensure_root(state)
  local old_location = root.placed_entity_index[unit_number]
  if old_location then
    local old_surface = ensure_surface(root, old_location.force_name, old_location.surface_name)
    local old_entity = old_surface and old_surface.placed_entities[unit_number] or nil
    if old_entity then
      change_placed_count(old_surface, old_entity.item_name, -1)
      change_split_claim_count(old_surface, old_entity.split_id, old_entity.item_name, -1)
      old_surface.placed_entities[unit_number] = nil
    end
  end

  local surface = ensure_surface(root, force_name, surface_name)
  surface.placed_entities[unit_number] = {
    unit_number = unit_number,
    force_name = force_name,
    item_name = item_name,
    entity_name = entity.entity_name,
    surface_name = surface_name,
    split_id = entity.split_id,
    placed_tick = entity.placed_tick
  }
  root.placed_entity_index[unit_number] = {
    force_name = force_name,
    surface_name = surface_name
  }
  change_placed_count(surface, item_name, 1)
  change_split_claim_count(surface, entity.split_id, item_name, 1)
  return true
end

function M.remove_placed_entity(state, unit_number)
  local root = ensure_root(state)
  local location = root.placed_entity_index[unit_number]
  if not location then
    return false
  end

  local surface = ensure_surface(root, location.force_name, location.surface_name)
  local entity = surface and surface.placed_entities[unit_number] or nil
  if not entity then
    root.placed_entity_index[unit_number] = nil
    return false
  end

  change_placed_count(surface, entity.item_name, -1)
  change_split_claim_count(surface, entity.split_id, entity.item_name, -1)
  surface.placed_entities[unit_number] = nil
  root.placed_entity_index[unit_number] = nil
  return true
end

function M.get_placed_count(state, force_name, surface_name, item_name)
  local normalized_item_name = normalize_item_name(item_name)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not (surface and normalized_item_name) then
    return 0
  end

  return surface.placed_counts[normalized_item_name] or 0
end

function M.add_production_input_exclusion(state, force_name, surface_name, item_name, count)
  local normalized_item_name = normalize_item_name(item_name)
  local normalized_count = normalize_non_negative_count(count)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not (surface and normalized_item_name) or normalized_count == 0 then
    return false
  end

  change_non_negative_count(surface.production_input_exclusions, normalized_item_name, normalized_count)
  return true
end

function M.get_production_totals(state, force_name, surface_name, item_name)
  local normalized_item_name = normalize_item_name(item_name)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not (surface and normalized_item_name) then
    return 0, 0
  end

  local totals = surface.production_totals[normalized_item_name]
  if not totals then
    return 0, 0
  end

  return totals.produced_total or 0, totals.consumed_total or 0
end

function M.sync_item_production_statistics(state, force_name, surface_name, statistics)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not (surface and statistics) then
    return false
  end

  local input_counts = statistics.input_counts or {}
  local output_counts = statistics.output_counts or {}
  local item_names = {}

  for item_name in pairs(input_counts) do
    item_names[item_name] = true
  end
  for item_name in pairs(output_counts) do
    item_names[item_name] = true
  end
  for item_name in pairs(surface.production_totals) do
    item_names[item_name] = true
  end
  for item_name in pairs(surface.production_input_exclusions) do
    item_names[item_name] = true
  end

  local handled = false

  for item_name in pairs(item_names) do
    local normalized_item_name = normalize_item_name(item_name)
    if normalized_item_name then
      local totals = ensure_production_total(surface, normalized_item_name)
      local current_input_count = normalize_statistics_count(input_counts[normalized_item_name])
      local current_output_count = normalize_statistics_count(output_counts[normalized_item_name])

      if current_input_count < totals.last_input_count or current_output_count < totals.last_output_count then
        totals.last_input_count = current_input_count
        totals.last_output_count = current_output_count
        handled = true
      else
        local produced_delta = current_input_count - totals.last_input_count
        local consumed_delta = current_output_count - totals.last_output_count
        local excluded_produced = math.min(produced_delta, surface.production_input_exclusions[normalized_item_name] or 0)
        local applied_produced_delta = produced_delta - excluded_produced

        if excluded_produced > 0 then
          change_non_negative_count(surface.production_input_exclusions, normalized_item_name, -excluded_produced)
        end

        if applied_produced_delta > 0 then
          totals.produced_total = totals.produced_total + applied_produced_delta
        end
        if consumed_delta > 0 then
          totals.consumed_total = totals.consumed_total + consumed_delta
        end
        if applied_produced_delta ~= 0 or consumed_delta ~= 0 then
          change_loose_stock(surface, normalized_item_name, applied_produced_delta - consumed_delta)
          handled = true
        end
        if excluded_produced ~= 0 then
          handled = true
        end

        totals.last_input_count = current_input_count
        totals.last_output_count = current_output_count
      end
    end
  end

  return handled
end

function M.mark_surface_uncertain(state, force_name, surface_name, tick, reason)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not surface then
    return false
  end

  if surface.uncertainty.since_tick == nil then
    surface.uncertainty.since_tick = tick
  end

  if reason and reason ~= "" then
    surface.uncertainty.reason = reason
  end

  return true
end

function M.clear_surface_uncertainty(state, force_name, surface_name)
  local surface = ensure_surface(ensure_root(state), force_name, surface_name)
  if not surface then
    return false
  end

  surface.uncertainty = {}
  return true
end

function M.get_surface_snapshot(state, force_name, surface_name, split_id)
  local resolved_force_name = normalize_force_name(force_name)
  local surface = ensure_surface(ensure_root(state), resolved_force_name, surface_name)
  if not surface then
    return {
      force_name = resolved_force_name,
      surface_name = surface_name,
      entries = {},
      uncertainty = {}
    }
  end

  local split_counts = (split_id ~= nil and surface.placed_counts_by_split_id[split_id]) or nil
  local base_entries = build_snapshot_entries(surface)
  local entries = {}
  for index, entry in ipairs(base_entries) do
    local copied_entry = copy_item_entry(entry)
    copied_entry.current_split_claim = split_counts and (split_counts[copied_entry.item_name] or 0) or 0
    entries[index] = copied_entry
  end

  return {
    force_name = resolved_force_name,
    surface_name = surface_name,
    entries = entries,
    uncertainty = {
      since_tick = surface.uncertainty.since_tick,
      reason = surface.uncertainty.reason
    }
  }
end

return M
