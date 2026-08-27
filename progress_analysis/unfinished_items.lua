-- One ordering policy for compact HUD lists. Rank by anticipated arrival
-- time when present (the long pole); fall back to remaining count.
local M = {}

function M.accumulate(into, blocker)
  local existing = into[blocker.item_name]
  if not existing then
    into[blocker.item_name] = {
      item_name = blocker.item_name,
      count = blocker.count,
      eta_ticks = blocker.eta_ticks,
      produced_per_minute = blocker.produced_per_minute or 0
    }
    return
  end
  existing.count = existing.count + blocker.count
  existing.eta_ticks = math.max(existing.eta_ticks or 0, blocker.eta_ticks or 0)
  existing.produced_per_minute = math.max(
    existing.produced_per_minute or 0,
    blocker.produced_per_minute or 0
  )
end

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
