local progress_tracker_store = require("progress_tracker_store")

local M = {}

-- Factorio starts a new character with items already in hand. Granting the same
-- counts into loose-stock tracking prevents the planner from acting as if the
-- run begins from an empty inventory.

local STARTING_ITEMS = {
  {name = "firearm-magazine", count = 10},
  {name = "iron-plate", count = 8},
  {name = "wood", count = 1},
  {name = "stone-furnace", count = 1},
  {name = "burner-mining-drill", count = 1}
}

local function ensure_registry(state)
  state.starting_loose_stock = state.starting_loose_stock or {}
  return state.starting_loose_stock
end

function M.items()
  local items = {}
  for index, entry in ipairs(STARTING_ITEMS) do
    items[index] = {
      name = entry.name,
      count = entry.count
    }
  end
  return items
end

function M.was_granted(state)
  return ensure_registry(state).granted == true
end

function M.grant_once(state, player)
  if not (player and player.valid and player.force and player.force.name and player.surface and player.surface.name) then
    return false
  end

  local registry = ensure_registry(state)
  if registry.granted == true then
    return false
  end

  for _, entry in ipairs(STARTING_ITEMS) do
    progress_tracker_store.adjust_loose_stock(state, player.force.name, player.surface.name, entry.name, entry.count)
  end

  registry.granted = true
  registry.force_name = player.force.name
  registry.surface_name = player.surface.name
  return true
end

return M
