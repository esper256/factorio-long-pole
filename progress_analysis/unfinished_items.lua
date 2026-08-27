-- One ordering policy for the compact lists below progress bars. Today the
-- largest numerical shortage is first; later this is the single place to rank
-- the same entries by assembly time or another long-pole estimate.
local M = {}

function M.sort(entries)
  table.sort(entries, function(left, right)
    if left.count == right.count then
      return left.item_name < right.item_name
    end
    return left.count > right.count
  end)
  return entries
end

return M
