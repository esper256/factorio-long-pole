-- Reconciles item and fluid production from Factorio's per-force, per-surface
-- statistics. Trees/rocks/wreck loot are not in these graphs; harvested counts
-- stay on the ledger from entity-removal snoopers.
--
-- Quality is summed: vanilla play does not split the ledger by quality yet.
-- Totals use the already-summed input_counts / output_counts so current-tick
-- samples are not double-counted after Factorio merges them.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

local function flow_rates(statistics, category, names)
  local rates = {}
  if not statistics.get_flow_count then
    return rates
  end
  local precision = defines.flow_precision_index.one_minute
  for name in pairs(names) do
    rates[name] = statistics.get_flow_count({
      name = name,
      category = category,
      precision_index = precision
    }) or 0
  end
  return rates
end

local function union_keys(...)
  local names = {}
  for index = 1, select("#", ...) do
    for name in pairs(select(index, ...) or {}) do
      names[name] = true
    end
  end
  return names
end

local function merge_counts(into, source)
  for name, count in pairs(source or {}) do
    into[name] = count
  end
end

local function merge_rates(into, statistics, category, names)
  for name, rate in pairs(flow_rates(statistics, category, names)) do
    into[name] = rate
  end
end

-- Item and fluid graphs are separate Factorio objects but one ledger surface.
-- Reconcile them as a single snapshot so applying fluids cannot zero items.
function M.on_second_tick(_event)
  local force = game.forces.player

  for _, surface in pairs(game.surfaces) do
    local produced = {}
    local consumed = {}
    local produced_rates = {}
    local consumed_rates = {}

    local item_statistics = force.get_item_production_statistics(surface)
    merge_counts(produced, item_statistics.input_counts)
    merge_counts(consumed, item_statistics.output_counts)
    local item_names = union_keys(item_statistics.input_counts, item_statistics.output_counts)
    merge_rates(produced_rates, item_statistics, "input", item_names)
    merge_rates(consumed_rates, item_statistics, "output", item_names)

    if force.get_fluid_production_statistics then
      local fluid_statistics = force.get_fluid_production_statistics(surface)
      merge_counts(produced, fluid_statistics.input_counts)
      merge_counts(consumed, fluid_statistics.output_counts)
      local fluid_names = union_keys(fluid_statistics.input_counts, fluid_statistics.output_counts)
      merge_rates(produced_rates, fluid_statistics, "input", fluid_names)
      merge_rates(consumed_rates, fluid_statistics, "output", fluid_names)
    end

    local ledger = long_pole_runtime_state.ledger()
    game_state.reconcile_product_statistics(ledger, surface.name, produced, consumed)
    game_state.reconcile_product_flow_rates(ledger, surface.name, produced_rates, consumed_rates)
  end
end

return M
