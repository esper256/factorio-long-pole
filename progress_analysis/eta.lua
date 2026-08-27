-- Finish-time estimate in ticks. Factory rate is items per minute from
-- production statistics. Hypothetical nonstop handcraft is added so zero-rate
-- items stay sortable (PRODUCT.md §2).
local M = {}

local TICKS_PER_MINUTE = 3600
local DEFAULT_HANDCRAFT_SECONDS = 0.5

function M.handcraft_per_minute(recipe_energy_seconds, crafting_speed)
  local energy = recipe_energy_seconds or DEFAULT_HANDCRAFT_SECONDS
  if energy <= 0 then
    energy = DEFAULT_HANDCRAFT_SECONDS
  end
  local speed = crafting_speed or 1
  if speed <= 0 then
    speed = 1
  end
  return 60 * speed / energy
end

function M.finish_ticks(remaining_count, produced_per_minute, handcraft_per_minute)
  local remaining = math.max(0, remaining_count or 0)
  if remaining <= 0 then
    return 0
  end
  local per_minute = math.max(0, produced_per_minute or 0) + math.max(0, handcraft_per_minute or 0)
  if per_minute <= 0 then
    per_minute = M.handcraft_per_minute(DEFAULT_HANDCRAFT_SECONDS, 1)
  end
  return remaining * TICKS_PER_MINUTE / per_minute
end

return M
