local progress_tracker_store = require("progress_tracker_store")

local M = {}

-- Small wrapper around the store so snoopers can express inventory deltas in
-- one place instead of each event handler open-coding stack iteration.

function M.adjust_item_stack(state, force_name, surface_name, item_name, count_delta)
  if not (force_name and surface_name and item_name and count_delta and count_delta ~= 0) then
    return false
  end

  return progress_tracker_store.adjust_loose_stock(state, force_name, surface_name, item_name, count_delta)
end

function M.adjust_from_item_stack(state, force_name, surface_name, item_stack, multiplier)
  if not item_stack then
    return false
  end

  local item_name = item_stack.name
  local count = tonumber(item_stack.count) or 0
  local scale = tonumber(multiplier) or 1
  if not item_name or count == 0 or scale == 0 then
    return false
  end

  return M.adjust_item_stack(state, force_name, surface_name, item_name, count * scale)
end

function M.adjust_from_inventory(state, force_name, surface_name, inventory, multiplier)
  if not inventory then
    return false
  end

  local handled = false
  local scale = tonumber(multiplier) or 1
  for index = 1, #inventory do
    local stack = inventory[index]
    if stack and stack.valid_for_read then
      handled = M.adjust_from_item_stack(state, force_name, surface_name, stack, scale) or handled
    end
  end

  return handled
end

return M
