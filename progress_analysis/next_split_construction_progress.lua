-- Readiness to build the next split, after reserving loose stock for the
-- current split's remaining construction requirements.
local game_state = require("game_state.game_state")
local unfinished_items = require("progress_analysis.unfinished_items")

local M = {}

local function current_remaining(current_split, state, split_start_placed_product_counts, item_name)
  local required = current_split:placement_item_count(item_name)
  local placed_now = game_state.total_placed_products(state, item_name)
  local placed_at_start = split_start_placed_product_counts[item_name] or 0
  local built = math.min(required, math.max(0, placed_now - placed_at_start))
  return required - built
end

function M.for_splits(current_split, next_split, state, split_start_placed_product_counts)
  local progress = {
    total = 0,
    done = 0,
    pending = 0,
    unfinished_items = {}
  }

  for _, item_name in ipairs(next_split.placement_item_names) do
    local required = next_split:placement_item_count(item_name)
    local loose_stock = math.max(0, game_state.total_loose_stock(state, item_name))
    local reserved_for_current = current_remaining(
      current_split,
      state,
      split_start_placed_product_counts,
      item_name
    )
    local ready = math.min(required, math.max(0, loose_stock - reserved_for_current))
    local shortfall = required - ready

    progress.total = progress.total + required
    progress.pending = progress.pending + ready
    if shortfall > 0 then
      progress.unfinished_items[#progress.unfinished_items + 1] = {
        item_name = item_name,
        count = shortfall
      }
    end
  end

  unfinished_items.sort(progress.unfinished_items)
  progress.tooltip = ("Next construction: %d ready to place · %d remaining")
    :format(progress.pending, progress.total - progress.pending)
  return progress
end

return M
