local progress_tracker_store = require("progress_tracker_store")
local player_context = require("progress_snoopers.player_context")
local stock_adjuster = require("progress_snoopers.stock_adjuster")

local M = {
  id = "entity-lifetime",
  subscriptions = {
    on_entity_died = "on_entity_died",
    script_raised_destroy = "on_script_raised_destroy",
    on_object_destroyed = "on_object_destroyed"
  }
}

local UNCERTAIN_TYPES = {
  ["container"] = true,
  ["logistic-container"] = true,
  ["infinity-container"] = true,
  ["temporary-container"] = true,
  ["assembling-machine"] = true,
  ["furnace"] = true,
  ["lab"] = true,
  ["rocket-silo"] = true,
  ["cargo-landing-pad"] = true,
  ["car"] = true,
  ["spider-vehicle"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["locomotive"] = true,
  ["roboport"] = true
}

local function entity_type(entity)
  return entity and (entity.type or (entity.prototype and entity.prototype.type)) or nil
end

local function should_mark_uncertain(entity)
  local resolved_type = entity_type(entity)
  if resolved_type and UNCERTAIN_TYPES[resolved_type] then
    return true
  end

  if entity and entity.get_inventory then
    return true
  end

  return false
end

local function forget_entity(state, event, entity, reason)
  local unit_number = entity and entity.unit_number or (event and event.useful_id) or nil
  local force_name = player_context.resolve_force_name(event, entity)
  local surface_name = player_context.resolve_surface_name(event, entity)
  local removed = progress_tracker_store.remove_placed_entity(state, unit_number)
  local marked = false

  if should_mark_uncertain(entity) then
    marked = progress_tracker_store.mark_surface_uncertain(
      state,
      force_name,
      surface_name,
      event and event.tick or nil,
      reason or "entity-destroyed-with-inventory"
    )
  elseif removed and not entity then
    marked = progress_tracker_store.mark_surface_uncertain(
      state,
      force_name,
      surface_name,
      event and event.tick or nil,
      reason or "tracked-entity-destroyed"
    )
  end

  local restored_loot = false
  if event and event.loot then
    restored_loot = stock_adjuster.adjust_from_inventory(
      state,
      force_name,
      surface_name,
      event.loot,
      1,
      {tick = event.tick}
    )
  end

  return removed or marked or restored_loot
end

function M.on_entity_died(state, event)
  local entity = event and event.entity or nil
  if entity and entity.valid == false then
    entity = event.entity
  end
  return forget_entity(state, event, entity, "entity-died")
end

function M.on_script_raised_destroy(state, event)
  local entity = event and event.entity or nil
  return forget_entity(state, event, entity, "script-raised-destroy")
end

function M.on_object_destroyed(state, event)
  local unit_number = event and (event.useful_id or event.unit_number) or nil
  if unit_number == nil then
    return false
  end

  return progress_tracker_store.remove_placed_entity(state, unit_number)
end

return M
