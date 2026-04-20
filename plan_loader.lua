local sample_plan = require("plan_sources.sample_plan")

local M = {}

local function shallow_copy_entries(entries)
  local copied = {}
  for index, entry in ipairs(entries or {}) do
    local entry_copy = {}
    for key, value in pairs(entry) do
      entry_copy[key] = value
    end
    copied[index] = entry_copy
  end
  return copied
end

local function copy_split(split)
  return {
    name = split.name,
    items = shallow_copy_entries(split.items),
    blueprints = shallow_copy_entries(split.blueprints),
    technologies = shallow_copy_entries(split.technologies),
    notes = split.notes or ""
  }
end

local function load_plan_for_player(_state)
  -- Future implementation:
  -- 1. inspect the player's blueprint library / selected blueprint book
  -- 2. find the Long Pole carrier book
  -- 3. decode the stored plan payload
  -- For now we return sample data through the same interface.
  local sample_splits = sample_plan.load()
  local splits = {}
  for index, split in ipairs(sample_splits) do
    splits[index] = copy_split(split)
  end
  return {
    source = "sample-plan",
    splits = splits
  }
end

function M.ensure_plan_loaded(state)
  if #state.splits > 0 then
    return false
  end

  local plan = load_plan_for_player(state)
  state.splits = plan.splits
  state.plan_source = plan.source
  return true
end

return M
