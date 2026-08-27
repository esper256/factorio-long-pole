-- Construction progress for one split. Plans have already normalized blueprint
-- entities into placement items, so curved rails and other entity variants
-- share the same requirement and the same event-accounted build progress.
-- Shortfalls walk to limiting ingredients (PRODUCT.md §3). Stock is spent
-- once across every placement item so two furnaces cannot both claim the
-- same 5 stone.
local game_state = require("game_state.game_state")
local unfinished_items = require("progress_analysis.unfinished_items")
local limiting_path = require("recipe_analysis.limiting_path")
local stock_pool = require("progress_analysis.stock_pool")

local M = {}

local function placed_this_split(split, state, split_start_placed_product_counts, item_name)
  local required = split:placement_item_count(item_name)
  local placed_now = game_state.total_placed_products(state, item_name)
  local placed_at_start = split_start_placed_product_counts[item_name] or 0
  return math.min(required, math.max(0, placed_now - placed_at_start))
end

local function analysis_context(state, extra, pool)
  extra = extra or {}
  return {
    crafting_speed = extra.crafting_speed or 1,
    observed_crafts = extra.observed_crafts,
    produced_per_minute = function(item_name)
      return game_state.total_produced_per_minute(state, item_name)
    end,
    loose_stock = function(item_name)
      return pool.have(item_name)
    end,
    take_stock = function(item_name, amount)
      return pool.take(item_name, amount)
    end
  }
end

function M.for_split(split, state, split_start_placed_product_counts, extra)
  local progress = {
    total = 0,
    done = 0,
    pending = 0,
    unfinished_items = {}
  }

  local pool = stock_pool.from_ledger(state)
  local blockers_by_name = {}
  local context = analysis_context(state, extra, pool)

  for _, item_name in ipairs(split.placement_item_names) do
    local required = split:placement_item_count(item_name)
    local done = placed_this_split(split, state, split_start_placed_product_counts, item_name)
    local remaining = required - done
    local pending = pool.take(item_name, remaining)
    local shortfall = remaining - pending
    progress.total = progress.total + required
    progress.done = progress.done + done
    progress.pending = progress.pending + pending
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
  local not_started = progress.total - progress.done - progress.pending
  progress.tooltip = ("Construction: %d placed · %d ready to place · %d remaining")
    :format(progress.done, progress.pending, not_started)
  return progress
end

return M
