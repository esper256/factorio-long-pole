-- Progress for metadata `item` directives. These are loose-stock goals, so
-- they move directly from not started to done without a pending state.
local game_state = require("game_state.game_state")
local unfinished_items = require("progress_analysis.unfinished_items")

local M = {}

function M.for_split(split, state)
  local progress = {
    total = 0,
    done = 0,
    pending = 0,
    unfinished_items = {}
  }

  for _, item_name in ipairs(split.extra_item_names) do
    local required = split:extra_item_count(item_name)
    progress.total = progress.total + required
    local done = math.min(required, math.max(0, game_state.total_loose_stock(state, item_name)))
    progress.done = progress.done + done
    local shortfall = required - done
    if shortfall > 0 then
      progress.unfinished_items[#progress.unfinished_items + 1] = {
        item_name = item_name,
        count = shortfall
      }
    end
  end

  unfinished_items.sort(progress.unfinished_items)
  local not_started = progress.total - progress.done
  progress.tooltip = ("Extra items: %d ready · %d remaining")
    :format(progress.done, not_started)
  return progress
end

return M
