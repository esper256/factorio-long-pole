-- Research progress for one split. Each technology contributes its full
-- science-pack cost, weighted by its own recorded completion fraction.
local game_state = require("game_state.game_state")

local M = {}

local function progress_fraction(state, technology_name)
  local research = state.research[technology_name]
  if not research then
    return 0
  end
  return research.researched and 1 or research.progress
end

local function rounded(count)
  return math.floor(count + 0.5)
end

function M.for_split(split, state, force)
  local progress = {
    total = 0,
    done = 0,
    pending = 0
  }
  local remaining_by_pack = {}

  for _, technology_name in ipairs(split.research_technology_names) do
    local technology = force.technologies[technology_name]
    assert(technology, "The current split requires unknown technology " .. technology_name)

    local complete_fraction = progress_fraction(state, technology_name)
    for _, ingredient in ipairs(technology.research_unit_ingredients) do
      local required = technology.research_unit_count * ingredient.amount
      progress.total = progress.total + required
      progress.done = progress.done + required * complete_fraction
      remaining_by_pack[ingredient.name] = (remaining_by_pack[ingredient.name] or 0)
        + required * (1 - complete_fraction)
    end
  end

  for pack_name, remaining in pairs(remaining_by_pack) do
    progress.pending = progress.pending + math.min(remaining, math.max(0, game_state.total_loose_stock(state, pack_name)))
  end

  local not_started = progress.total - progress.done - progress.pending
  progress.tooltip = ("Research: %d complete · %d science ready · %d remaining")
    :format(rounded(progress.done), rounded(progress.pending), rounded(not_started))
  return progress
end

return M
