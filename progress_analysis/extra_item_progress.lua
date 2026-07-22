-- Progress for metadata `item` directives. These are loose-stock goals, so
-- they move directly from not started to done without a pending state.
local game_state = require("game_state.game_state")

local M = {}

function M.for_split(split, state)
  local progress = {
    total = 0,
    done = 0,
    pending = 0
  }

  for _, item_name in ipairs(split.extra_item_names) do
    local required = split:extra_item_count(item_name)
    progress.total = progress.total + required
    progress.done = progress.done + math.min(required, math.max(0, game_state.total_loose_stock(state, item_name)))
  end

  local not_started = progress.total - progress.done
  progress.tooltip = ("Extra items: %d ready · %d remaining")
    :format(progress.done, not_started)
  return progress
end

return M
