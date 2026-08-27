-- Construction progress for one split. Plans have already normalized blueprint
-- entities into placement items, so curved rails and other entity variants
-- share the same requirement and the same event-accounted build progress.
local game_state = require("game_state.game_state")
local unfinished_items = require("progress_analysis.unfinished_items")

local M = {}

local function progress_for_item(split, state, split_start_placed_product_counts, item_name)
  local required = split:placement_item_count(item_name)
  local placed_now = game_state.total_placed_products(state, item_name)
  local placed_at_start = split_start_placed_product_counts[item_name] or 0
  local done = math.min(required, math.max(0, placed_now - placed_at_start))

  local loose_items = math.max(0, game_state.total_loose_stock(state, item_name))
  local pending = math.min(required - done, loose_items)
  return done, pending, required - done - pending
end

function M.for_split(split, state, split_start_placed_product_counts)
  local progress = {
    total = 0,
    done = 0,
    pending = 0,
    unfinished_items = {}
  }

  for _, item_name in ipairs(split.placement_item_names) do
    local required = split:placement_item_count(item_name)
    local done, pending, shortfall = progress_for_item(split, state, split_start_placed_product_counts, item_name)
    progress.total = progress.total + required
    progress.done = progress.done + done
    progress.pending = progress.pending + pending
    if shortfall > 0 then
      progress.unfinished_items[#progress.unfinished_items + 1] = {
        item_name = item_name,
        count = shortfall
      }
    end
  end

  unfinished_items.sort(progress.unfinished_items)
  local not_started = progress.total - progress.done - progress.pending
  progress.tooltip = ("Construction: %d placed · %d ready to place · %d remaining")
    :format(progress.done, progress.pending, not_started)
  return progress
end

return M
