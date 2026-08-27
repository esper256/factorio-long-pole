-- Next-split production demand: that split's blueprint placement items plus
-- its extra stock, after reserving loose stock still needed to place the
-- current print. This is what the factory should be making (PRODUCT.md §11-12).
local game_state = require("game_state.game_state")
local unfinished_items = require("progress_analysis.unfinished_items")
local limiting_path = require("recipe_analysis.limiting_path")

local M = {}

local function current_remaining(current_split, state, split_start_placed_product_counts, item_name)
  local required = current_split:placement_item_count(item_name)
  local placed_now = game_state.total_placed_products(state, item_name)
  local placed_at_start = split_start_placed_product_counts[item_name] or 0
  local built = math.min(required, math.max(0, placed_now - placed_at_start))
  return required - built
end

local function analysis_context(state, extra)
  extra = extra or {}
  return {
    crafting_speed = extra.crafting_speed or 1,
    observed_crafts = extra.observed_crafts,
    produced_per_minute = function(item_name)
      return game_state.total_produced_per_minute(state, item_name)
    end,
    loose_stock = function(item_name)
      return math.max(0, game_state.total_loose_stock(state, item_name) - (extra.reserved[item_name] or 0))
    end
  }
end

function M.for_splits(current_split, next_split, state, split_start_placed_product_counts, extra)
  local progress = {
    total = 0,
    done = 0,
    pending = 0,
    unfinished_items = {}
  }

  local reserved = {}
  for _, item_name in ipairs(current_split.placement_item_names) do
    reserved[item_name] = current_remaining(
      current_split,
      state,
      split_start_placed_product_counts,
      item_name
    )
  end

  local blockers_by_name = {}
  local context = analysis_context(state, {
    crafting_speed = extra and extra.crafting_speed,
    observed_crafts = extra and extra.observed_crafts,
    reserved = reserved
  })

  for _, item_name in ipairs(next_split.production_item_names) do
    local required = next_split:production_item_count(item_name)
    local loose_stock = math.max(0, game_state.total_loose_stock(state, item_name))
    local reserved_for_current = reserved[item_name] or 0
    local ready = math.min(required, math.max(0, loose_stock - reserved_for_current))
    local shortfall = required - ready

    progress.total = progress.total + required
    progress.pending = progress.pending + ready
    if shortfall > 0 then
      for _, blocker in ipairs(limiting_path.blockers(item_name, shortfall, context)) do
        unfinished_items.accumulate(blockers_by_name, blocker)
      end
    end
  end

  for _, blocker in pairs(blockers_by_name) do
    progress.unfinished_items[#progress.unfinished_items + 1] = blocker
  end

  unfinished_items.sort(progress.unfinished_items)
  progress.tooltip = ("Next production: %d ready · %d remaining")
    :format(progress.pending, progress.total - progress.pending)
  return progress
end

return M
