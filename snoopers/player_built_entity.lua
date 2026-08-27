-- Records entities directly built by a player and the items the build spent.
--
-- Entity names and item names are intentionally recorded independently:
-- Factorio exposes the created entity and the complete consumed-items inventory
-- in this event, so no guessed prototype mapping is necessary.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

M.event_names = {
  "on_built_entity"
}

local function product_counts(items)
  local counts = {}

  for _, item in ipairs(items) do
    counts[item.name] = (counts[item.name] or 0) + item.count
  end

  return counts
end

function M.on_event(event)
  if event.entity.type == "entity-ghost" then
    return
  end

  -- Map-editor placements can have an invalid temporary inventory because they
  -- do not consume an item. Ignore them rather than attempting to account for
  -- an entity without its corresponding placed product.
  local consumed_items = event.consumed_items
  if consumed_items == nil or consumed_items.valid == false then
    return
  end

  local runtime_state = long_pole_runtime_state.get()
  local surface = game_state.surface(runtime_state.ledger, event.entity.surface.name)

  surface:record_placed_entities({
    [event.entity.name] = 1
  })

  surface:record_products_placed(product_counts(consumed_items.get_contents()))
end

return M
