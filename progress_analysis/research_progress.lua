-- Research progress for one split. Green is packs already consumed into
-- science. Remaining work is lab throughput, not packs sitting in chests.
local game_state = require("game_state.game_state")
local unfinished_items = require("progress_analysis.unfinished_items")
local eta = require("progress_analysis.eta")

local M = {}

local function progress_fraction(state, force, technology_name)
  local technology = force.technologies[technology_name]
  if technology and technology.researched then
    return 1
  end
  if force.current_research and force.current_research.name == technology_name then
    return force.research_progress or 0
  end
  if technology and technology.saved_progress then
    return technology.saved_progress
  end
  local research = state.research[technology_name]
  if not research then
    return 0
  end
  return research.researched and 1 or research.progress
end

local function rounded(count)
  return math.floor(count + 0.5)
end

local function lab_consume_per_minute(state, pack_name)
  local from_stats = game_state.total_consumed_per_minute(state, pack_name)
  if from_stats > 0 then
    return from_stats
  end
  local working = state.lab_working_count or 0
  -- One working lab at 5s/unit, 1 pack/unit ≈ 12 packs/minute. Used only so
  -- zero-lab remaining work stays sortable; the HUD still shows 0 labs.
  if working <= 0 then
    return 0
  end
  return working * 12
end

function M.for_split(split, state, force)
  local progress = {
    total = 0,
    done = 0,
    pending = 0,
    unfinished_items = {},
    working_labs = state.lab_working_count or 0
  }
  local remaining_by_pack = {}

  for _, technology_name in ipairs(split.research_technology_names) do
    local technology = force.technologies[technology_name]
    assert(technology, "The current split requires unknown technology " .. technology_name)

    local complete_fraction = progress_fraction(state, force, technology_name)
    for _, ingredient in ipairs(technology.research_unit_ingredients) do
      local required = technology.research_unit_count * ingredient.amount
      progress.total = progress.total + required
      progress.done = progress.done + required * complete_fraction
      remaining_by_pack[ingredient.name] = (remaining_by_pack[ingredient.name] or 0)
        + required * (1 - complete_fraction)
    end
  end

  for pack_name, remaining in pairs(remaining_by_pack) do
    if remaining > 0 then
      local consume_rate = lab_consume_per_minute(state, pack_name)
      progress.unfinished_items[#progress.unfinished_items + 1] = {
        item_name = pack_name,
        count = remaining,
        eta_ticks = eta.finish_ticks(remaining, consume_rate, 0),
        produced_per_minute = consume_rate
      }
    end
  end

  unfinished_items.sort(progress.unfinished_items)
  local not_started = progress.total - progress.done
  progress.tooltip = ("Research: %d consumed in labs · %d remaining · %d labs working")
    :format(rounded(progress.done), rounded(not_started), progress.working_labs)
  return progress
end

return M
