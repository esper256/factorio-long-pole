-- Entity removal: player/robot/platform mining, death, and script destroy.
--
-- Placeable buildings unplace the placement item.
-- Trees, rocks, fish, and crash-site wrecks harvest returned buffer items
-- because those drops are not on the production graph (PRODUCT.md §14).
--
-- Ore patches are not tracked here. Hand mining and mining drills both
-- already increment Factorio production statistics; that graph is the only
-- source for patch ore. Unknown / untyped entities are not harvested.
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

-- Only these map objects drop items that Factorio omits from production stats.
-- Anything else, including nil/unknown types, is not a harvest source.
local HARVESTED_ENTITY_TYPES = {
  tree = true,
  ["simple-entity"] = true,
  ["simple-entity-with-owner"] = true,
  fish = true
}

local WRECK_ENTITY_TYPES = {
  container = true,
  ["logistic-container"] = true,
  ["infinity-container"] = true
}

local function named_prototype(entity)
  if prototypes and prototypes.entity and entity.name then
    return prototypes.entity[entity.name]
  end
end

local function entity_prototype(entity)
  return entity.prototype or named_prototype(entity)
end

local function entity_type_name(entity)
  local type_name = entity.type
  if type(type_name) == "string" and type_name ~= "" then
    return type_name
  end
  local proto = entity_prototype(entity)
  return proto and proto.type
end

local function product_counts(items)
  local counts = {}
  if not items then
    return counts
  end
  if items[1] ~= nil then
    for _, item in ipairs(items) do
      if item.name then
        counts[item.name] = (counts[item.name] or 0) + (item.count or 0)
      end
    end
    return counts
  end
  for name, count in pairs(items) do
    if type(name) == "string" and type(count) == "number" then
      counts[name] = (counts[name] or 0) + count
    end
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
  local proto = entity_prototype(entity)
  local items_to_place = proto and proto.items_to_place_this
  if not items_to_place or #items_to_place == 0 then
    return nil
  end
  return items_to_place[1]
end

-- Production statistics already count this ore. Dying resources may omit
-- entity.type; named prototype, resource_category, and resource amount still
-- identify a patch. Reading amount on a non-resource errors in Factorio.
local function is_ore_patch(entity)
  if entity_type_name(entity) == "resource" then
    return true
  end
  local proto = entity_prototype(entity)
  if proto ~= nil and (proto.type == "resource" or proto.resource_category ~= nil) then
    return true
  end
  local ok, amount = pcall(function()
    return entity.amount
  end)
  return ok and type(amount) == "number"
end

local function is_loot_source(entity)
  if is_ore_patch(entity) then
    return false
  end
  local type_name = entity_type_name(entity)
  if type_name == nil or type_name == "entity-ghost" then
    return false
  end
  if HARVESTED_ENTITY_TYPES[type_name] then
    return true
  end
  return WRECK_ENTITY_TYPES[type_name] == true and placement_item(entity) == nil
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
  if not entity or entity_type_name(entity) == "entity-ghost" or is_ore_patch(entity) then
    return
  end

  local runtime_state = long_pole_runtime_state.get()
  local surface = game_state.surface(runtime_state.ledger, entity.surface.name)
  local died = event.died == true
  if not died and defines and defines.events and event.name then
    died = event.name == defines.events.on_entity_died
      or event.name == defines.events.script_raised_destroy
  end

  if placement_item(entity) then
    local returned_items = buffer_counts(event)
    local placement_items = returned_placement_item_counts(entity, returned_items)
    if placement_items then
      if died then
        surface:record_destroyed_entities({ [entity.name] = 1 })
        surface:record_products_destroyed(placement_items)
      else
        surface:record_unplaced_entities({ [entity.name] = 1 })
        surface:record_products_unplaced(placement_items)
      end
    end
  elseif is_loot_source(entity) and not died then
    surface:record_products_harvested(buffer_counts(event))
  end
end

return M
