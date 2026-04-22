local player_context = require("progress_snoopers.player_context")
local progress_tracker_store = require("progress_tracker_store")
local stock_adjuster = require("progress_snoopers.stock_adjuster")

local M = {
  id = "hand-crafting",
  subscriptions = {
    on_pre_player_crafted_item = "on_pre_player_crafted_item",
    on_player_crafted_item = "on_player_crafted_item",
    on_player_cancelled_crafting = "on_player_cancelled_crafting"
  }
}

function M.on_pre_player_crafted_item(state, event)
  local force_name = player_context.resolve_force_name(event)
  local surface_name = player_context.resolve_surface_name(event)
  if not (force_name and surface_name and event and event.items) then
    return false
  end

  -- Reserve ingredients immediately so hand crafting does not look like stock
  -- that is still available to satisfy current or next split requirements.
  return stock_adjuster.adjust_from_inventory(state, force_name, surface_name, event.items, -1)
end

function M.on_player_crafted_item(state, event)
  local force_name = player_context.resolve_force_name(event)
  local surface_name = player_context.resolve_surface_name(event)
  if not (force_name and surface_name and event and event.item_stack) then
    return false
  end

  local adjusted_loose_stock = stock_adjuster.adjust_from_item_stack(state, force_name, surface_name, event.item_stack, 1)
  local excluded_from_production_stats = progress_tracker_store.add_production_input_exclusion(
    state,
    force_name,
    surface_name,
    event.item_stack.name,
    event.item_stack.count
  )

  -- Hand-crafted outputs appear in production statistics, so excluding them
  -- there prevents them from being counted once by the event and again by polling.
  return adjusted_loose_stock or excluded_from_production_stats
end

function M.on_player_cancelled_crafting(state, event)
  local force_name = player_context.resolve_force_name(event)
  local surface_name = player_context.resolve_surface_name(event)
  if not (force_name and surface_name and event and event.items) then
    return false
  end

  return stock_adjuster.adjust_from_inventory(state, force_name, surface_name, event.items, 1)
end

return M
