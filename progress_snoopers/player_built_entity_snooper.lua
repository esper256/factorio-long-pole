local progress_tracker_store = require("progress_tracker_store")
local entity_item_resolver = require("progress_snoopers.entity_item_resolver")
local player_context = require("progress_snoopers.player_context")
local stock_adjuster = require("progress_snoopers.stock_adjuster")

local M = {
  id = "player-built-entity",
  subscriptions = {
    on_built_entity = "on_built_entity",
    on_robot_built_entity = "on_robot_built_entity"
  }
}

local function current_split_id(state)
  local split = state and state.splits and state.splits[state.current_split_index] or nil
  return split and split.id or nil
end

function M.on_built_entity(state, event)
  local entity = event and (event.created_entity or event.entity) or nil
  if not (entity and entity.valid) then
    return false
  end

  local force_name = player_context.resolve_force_name(event, entity)
  local surface_name = player_context.resolve_surface_name(event, entity)
  local item_name = entity_item_resolver.resolve_item_name(event, entity)
  if not item_name then
    return false
  end

  local consumed_loose_stock = stock_adjuster.adjust_from_inventory(
    state,
    force_name,
    surface_name,
    event and event.consumed_items or nil,
    -1,
    {tick = event and event.tick or nil}
  )
  local tracked_placed_entity = progress_tracker_store.upsert_placed_entity(state, {
    unit_number = entity.unit_number,
    force_name = force_name,
    item_name = item_name,
    entity_name = entity.name,
    surface_name = surface_name,
    split_id = current_split_id(state),
    placed_tick = event.tick
  })

  if entity and rawget(_G, "script") and script.register_on_object_destroyed then
    pcall(script.register_on_object_destroyed, entity)
  end

  return consumed_loose_stock or tracked_placed_entity
end

function M.on_robot_built_entity(state, event)
  local entity = event and (event.created_entity or event.entity) or nil
  if not (entity and entity.valid) then
    return false
  end

  local force_name = player_context.resolve_force_name(event, entity)
  local surface_name = player_context.resolve_surface_name(event, entity)
  local item_name = entity_item_resolver.resolve_item_name(event, entity)
  if not item_name then
    return false
  end

  local consumed_loose_stock = stock_adjuster.adjust_from_item_stack(
    state,
    force_name,
    surface_name,
    event and event.stack or nil,
    -1,
    {tick = event and event.tick or nil}
  )
  local tracked_placed_entity = progress_tracker_store.upsert_placed_entity(state, {
    unit_number = entity.unit_number,
    force_name = force_name,
    item_name = item_name,
    entity_name = entity.name,
    surface_name = surface_name,
    split_id = current_split_id(state),
    placed_tick = event.tick
  })

  if entity and rawget(_G, "script") and script.register_on_object_destroyed then
    pcall(script.register_on_object_destroyed, entity)
  end

  return consumed_loose_stock or tracked_placed_entity
end

return M
