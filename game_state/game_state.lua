local M = {}

local STORAGE_VERSION = 1

local SurfaceMethods = {}
local SurfaceViewMetatable = {
  __index = SurfaceMethods
}

-- Mutable runtime game-state ledger.
--
-- Purpose:
-- - hold the mod's best current accounting of what has been produced,
--   consumed, placed, destroyed, and researched
-- - separate surface-scoped stock/accounting from global research state
--
-- Usage:
-- - create one state with `new()`
-- - advance its clock with `set_clock_tick(...)`
-- - bind a surface view with `surface(state, surface_name)`
-- - record incremental deltas with `record_*`
-- - apply reckonings/corrections with `set_*`
--
-- Design stance:
-- - this object is intentionally mutable
-- - it is expected to be updated frequently, potentially every tick
-- - avoid copy-heavy patterns here; debug/test rendering belongs elsewhere

-- Count tables are Lua maps from prototype name to non-negative count, e.g.
-- {["iron-plate"] = 120, ["gear-wheel"] = 40}.
--
-- The public API is intentionally split into:
-- - product accounting: produced / consumed / destroyed
-- - entity placement accounting: placed in the world
--
-- Entity placement still updates the product ledger internally because placing
-- an entity spends the corresponding item/fluid from loose stock.
local function sorted_keys(map)
  local names = {}
  for name in pairs(map or {}) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

local function surface_data(state, surface_name)
  local existing = state.surfaces[surface_name]
  if existing then
    return existing
  end

  local created = {
    products = {},
    placed_entities = {}
  }
  state.surfaces[surface_name] = created
  return created
end

local function product_entry(state, surface_name, product_name)
  local products = surface_data(state, surface_name).products
  local entry = products[product_name]
  if entry then
    return entry
  end

  entry = {
    produced = 0,
    consumed = 0,
    placed = 0,
    destroyed = 0
  }
  products[product_name] = entry
  return entry
end

local function placed_entity_entry(state, surface_name, entity_name)
  local placed_entities = surface_data(state, surface_name).placed_entities
  local entry = placed_entities[entity_name]
  if entry then
    return entry
  end

  entry = {
    placed = 0,
    destroyed = 0
  }
  placed_entities[entity_name] = entry
  return entry
end

local function research_entry(state, technology_name)
  local entry = state.research[technology_name]
  if entry then
    return entry
  end

  entry = {
    researched = false,
    progress = 0
  }
  state.research[technology_name] = entry
  return entry
end

local function add_product_counts(state, surface_name, field_name, counts_by_name)
  for product_name, count in pairs(counts_by_name) do
    assert(count >= 0, product_name .. " must be non-negative")
    local entry = product_entry(state, surface_name, product_name)
    entry[field_name] = entry[field_name] + count
  end
end

local function set_product_counts(state, surface_name, field_name, counts_by_name)
  for product_name, count in pairs(counts_by_name) do
    assert(count >= 0, product_name .. " must be non-negative")
    local entry = product_entry(state, surface_name, product_name)
    entry[field_name] = count
  end
end

local function add_placed_entity_counts(state, surface_name, field_name, counts_by_name)
  for entity_name, count in pairs(counts_by_name) do
    assert(count >= 0, entity_name .. " must be non-negative")
    local entry = placed_entity_entry(state, surface_name, entity_name)
    entry[field_name] = entry[field_name] + count
  end
end

local function set_placed_entity_counts(state, surface_name, field_name, counts_by_name)
  for entity_name, count in pairs(counts_by_name) do
    assert(count >= 0, entity_name .. " must be non-negative")
    local entry = placed_entity_entry(state, surface_name, entity_name)
    entry[field_name] = count
  end
end

function M.new(clock_tick)
  return {
    storage_version = STORAGE_VERSION,
    clock = {
      tick = clock_tick or 0
    },
    surfaces = {},
    research = {}
  }
end

function M.set_clock_tick(state, clock_tick)
  assert(clock_tick >= 0, "clock_tick must be non-negative")
  state.clock.tick = clock_tick
end

function M.surface(state, surface_name)
  assert(surface_name ~= "", "surface_name must be non-empty")
  return setmetatable({
    state = state,
    surface_name = surface_name
  }, SurfaceViewMetatable)
end

function M.set_research(state, technology_name, researched, progress)
  local entry = research_entry(state, technology_name)
  entry.researched = researched == true
  entry.progress = progress or 0
  assert(entry.progress >= 0, technology_name .. " progress must be non-negative")
  return entry
end

function M.loose_stock(product)
  return (product.produced or 0) - (product.consumed or 0) - (product.placed or 0) - (product.destroyed or 0)
end

-- Deterministic iteration helpers are for test/debug output only.
function M.sorted_surface_names(state)
  return sorted_keys(state.surfaces)
end

function M.sorted_product_names(surface_state)
  return sorted_keys(surface_state.products)
end

function M.sorted_placed_entity_names(surface_state)
  return sorted_keys(surface_state.placed_entities)
end

function M.sorted_research_names(state)
  return sorted_keys(state.research)
end

function SurfaceMethods.record_products_produced(self, counts_by_name)
  add_product_counts(self.state, self.surface_name, "produced", counts_by_name)
end

function SurfaceMethods.record_products_consumed(self, counts_by_name)
  add_product_counts(self.state, self.surface_name, "consumed", counts_by_name)
end

function SurfaceMethods.record_entities_placed(self, counts_by_name)
  add_product_counts(self.state, self.surface_name, "placed", counts_by_name)
end

function SurfaceMethods.record_products_destroyed(self, counts_by_name)
  add_product_counts(self.state, self.surface_name, "destroyed", counts_by_name)
end

function SurfaceMethods.set_products_produced(self, counts_by_name)
  set_product_counts(self.state, self.surface_name, "produced", counts_by_name)
end

function SurfaceMethods.set_products_consumed(self, counts_by_name)
  set_product_counts(self.state, self.surface_name, "consumed", counts_by_name)
end

function SurfaceMethods.set_entities_placed(self, counts_by_name)
  set_product_counts(self.state, self.surface_name, "placed", counts_by_name)
end

function SurfaceMethods.set_products_destroyed(self, counts_by_name)
  set_product_counts(self.state, self.surface_name, "destroyed", counts_by_name)
end

function SurfaceMethods.record_placed_entities(self, counts_by_name)
  add_placed_entity_counts(self.state, self.surface_name, "placed", counts_by_name)
end

function SurfaceMethods.record_destroyed_entities(self, counts_by_name)
  add_placed_entity_counts(self.state, self.surface_name, "destroyed", counts_by_name)
end

function SurfaceMethods.set_placed_entities(self, counts_by_name)
  set_placed_entity_counts(self.state, self.surface_name, "placed", counts_by_name)
end

function SurfaceMethods.set_destroyed_entities(self, counts_by_name)
  set_placed_entity_counts(self.state, self.surface_name, "destroyed", counts_by_name)
end

return M
