-- Reverses placement accounting when a player mines a placed entity.
--
-- Returned items are used only to identify which placement item to unplace;
-- they are not recorded as newly produced.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

M.event_names = {
  "on_player_mined_entity"
}

local HARVESTED_ENTITY_TYPES = {
  tree = true,
  ["simple-entity"] = true
}

local function product_counts(items)
  local counts = {}

  for _, item in ipairs(items) do
    counts[item.name] = (counts[item.name] or 0) + item.count
  end

  return counts
end

local function returned_placement_item_counts(entity, returned_items)
  for _, item_to_place in ipairs(entity.prototype.items_to_place_this or {}) do
    if (returned_items[item_to_place.name] or 0) >= item_to_place.count then
      return {
        [item_to_place.name] = item_to_place.count
      }
    end
  end

  return nil
end

function M.on_event(event)
  if event.entity.type == "entity-ghost" then
    return
  end

  local runtime_state = long_pole_runtime_state.get()
  local surface = game_state.surface(runtime_state.debug_game_state, event.entity.surface.name)
  local items_to_place = event.entity.prototype.items_to_place_this
  local is_harvested_source = HARVESTED_ENTITY_TYPES[event.entity.type]

  if not is_harvested_source and not items_to_place then
    return
  end

  local returned_items = product_counts(event.buffer.get_contents())
  local placement_items = returned_placement_item_counts(event.entity, returned_items)

  if placement_items then
    surface:record_unplaced_entities({
      [event.entity.name] = 1
    })
    surface:record_products_unplaced(placement_items)
  end

  if is_harvested_source then
    surface:record_products_harvested(returned_items)
  end
end

return M
