-- One ordering policy for compact HUD lists. Rank by anticipated arrival
-- time when present (the long pole); fall back to remaining count.
local M = {}

function M.sort(entries)
  table.sort(entries, function(left, right)
    local left_eta = left.eta_ticks
    local right_eta = right.eta_ticks
    if left_eta ~= nil or right_eta ~= nil then
      left_eta = left_eta or -1
      right_eta = right_eta or -1
      if left_eta ~= right_eta then
        return left_eta > right_eta
      end
    end
    if left.count == right.count then
      return left.item_name < right.item_name
    end
    return left.count > right.count
  end)
  return entries
end

return M
