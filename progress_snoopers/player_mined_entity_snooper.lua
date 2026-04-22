local player_context = require("progress_snoopers.player_context")
local progress_tracker_store = require("progress_tracker_store")
local stock_adjuster = require("progress_snoopers.stock_adjuster")

local M = {
  id = "player-mined-entity",
  subscriptions = {
    on_player_mined_entity = "on_player_mined_entity",
    on_robot_mined_entity = "on_robot_mined_entity"
  }
}

local function exclude_resource_mining_from_production_stats(state, force_name, surface_name, entity, inventory)
  if not (entity and entity.type == "resource" and inventory) then
    return false
  end

  -- Resource mining increases production statistics even though we already see
  -- the exact mined stacks here. Exclude those deltas so polling does not add them twice.
  local handled = false
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read then
      handled = progress_tracker_store.add_production_input_exclusion(
        state,
        force_name,
        surface_name,
        stack.name,
        stack.count
      ) or handled
    end
  end

  return handled
end

function M.on_player_mined_entity(state, event)
  local entity = event and event.entity or nil
  local force_name = player_context.resolve_force_name(event, entity)
  local surface_name = player_context.resolve_surface_name(event, entity)
  if not (force_name and surface_name and event and event.buffer) then
    return false
  end

  local removed_placed_entity = progress_tracker_store.remove_placed_entity(state, entity and entity.unit_number or nil)
  local restored_loose_stock = stock_adjuster.adjust_from_inventory(state, force_name, surface_name, event.buffer, 1)
  local excluded_resource_mining = exclude_resource_mining_from_production_stats(state, force_name, surface_name, entity, event.buffer)
  return removed_placed_entity or restored_loose_stock or excluded_resource_mining
end

function M.on_robot_mined_entity(state, event)
  local entity = event and event.entity or nil
  local force_name = player_context.resolve_force_name(event, entity)
  local surface_name = player_context.resolve_surface_name(event, entity)
  if not (force_name and surface_name and event and event.buffer) then
    return false
  end

  local removed_placed_entity = progress_tracker_store.remove_placed_entity(state, entity and entity.unit_number or nil)
  local restored_loose_stock = stock_adjuster.adjust_from_inventory(state, force_name, surface_name, event.buffer, 1)
  local excluded_resource_mining = exclude_resource_mining_from_production_stats(state, force_name, surface_name, entity, event.buffer)
  return removed_placed_entity or restored_loose_stock or excluded_resource_mining
end

return M
