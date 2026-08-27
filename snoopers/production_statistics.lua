-- Reconciles item production and consumption from Factorio's authoritative
-- per-force, per-surface production statistics.
--
-- The ledger is currently quality-agnostic, so every quality of an item is
-- summed into that item's single counter. Quality-aware accounting can replace
-- this aggregation when the domain model gains a quality dimension.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

local function counts_by_item_name(quality_counts)
  local counts = {}

  for _, counts_for_quality in pairs(quality_counts) do
    for item_name, count in pairs(counts_for_quality) do
      counts[item_name] = (counts[item_name] or 0) + count
    end
  end

  return counts
end

local function add_counts(target, additions)
  for item_name, count in pairs(additions) do
    target[item_name] = (target[item_name] or 0) + count
  end
end

local function complete_counts(total_quality_counts, current_sample_quality_counts)
  local counts = counts_by_item_name(total_quality_counts)

  -- Factorio merges current samples into total counts at the end of a tick.
  -- Including them makes this snapshot correct on either side of that merge.
  add_counts(counts, counts_by_item_name(current_sample_quality_counts))
  return counts
end

function M.on_second_tick(_event)
  local runtime_state = long_pole_runtime_state.get()
  local force = game.forces.player

  for _, surface in pairs(game.surfaces) do
    local statistics = force.get_item_production_statistics(surface)
    local produced_counts = complete_counts(
      statistics.input_quality_counts,
      statistics.current_input_quality_samples
    )
    game_state.reconcile_product_statistics(
      runtime_state.debug_game_state,
      surface.name,
      produced_counts,
      complete_counts(statistics.output_quality_counts, statistics.current_output_quality_samples)
    )
  end
end

return M
