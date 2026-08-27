-- Entity removal: player/robot/platform mining, death, and script destroy.
--
-- Placeable buildings unplace the placement item. Trees, rocks, and other
-- non-resource entities without a placement item (crash-site wrecks) harvest
-- returned buffer items. Those drops are not in production statistics.
-- Player-built chests have a placement item, so emptying them is not harvest.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

M.event_names = {
  "on_player_mined_entity",
  "on_robot_mined_entity",
  "on_space_platform_mined_entity",
  "on_entity_died",
  "script_raised_destroy"
}

local HARVESTED_ENTITY_TYPES = {
  tree = true,
  ["simple-entity"] = true,
  fish = true
}

local function product_counts(items)
  local counts = {}
  for _, item in ipairs(items or {}) do
    counts[item.name] = (counts[item.name] or 0) + item.count
  end
  return counts
end

local function buffer_counts(event)
  if not (event.buffer and event.buffer.get_contents) then
    return {}
  end
  return product_counts(event.buffer.get_contents())
end

local function placement_item(entity)
  local items_to_place = entity.prototype and entity.prototype.items_to_place_this
  if not items_to_place or #items_to_place == 0 then
    return nil
  end
  return items_to_place[1]
end

local function is_loot_source(entity)
  if entity.type == "resource" or entity.type == "entity-ghost" then
    return false
  end
  if HARVESTED_ENTITY_TYPES[entity.type] then
    return true
  end
  return placement_item(entity) == nil
end

local function returned_placement_item_counts(entity, returned_items)
  local item = placement_item(entity)
  if not item then
    return nil
  end
  if (returned_items[item.name] or 0) >= item.count then
    return { [item.name] = item.count }
  end
  -- Death/script destroy has no buffer; still unplace the canonical item.
  if not next(returned_items) then
    return { [item.name] = item.count }
  end
  return nil
end

function M.on_event(event)
  local entity = event.entity
  if not entity or entity.type == "entity-ghost" or entity.type == "resource" then
    return
  end

  local runtime_state = long_pole_runtime_state.get()
  local surface = game_state.surface(runtime_state.ledger, entity.surface.name)
  local returned_items = buffer_counts(event)
  local placement_items = returned_placement_item_counts(entity, returned_items)
  local died = event.died == true
  if not died and defines and defines.events and event.name then
    died = event.name == defines.events.on_entity_died
      or event.name == defines.events.script_raised_destroy
  end

  if placement_items then
    if died then
      surface:record_destroyed_entities({ [entity.name] = 1 })
      surface:record_products_destroyed(placement_items)
    else
      surface:record_unplaced_entities({ [entity.name] = 1 })
      surface:record_products_unplaced(placement_items)
    end
  elseif is_loot_source(entity) and not died then
    surface:record_products_harvested(returned_items)
  end
end

return M
