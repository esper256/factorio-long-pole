-- Domain view of a loaded speedrun plan, immutable by convention.
--
-- storage/blueprint_book_plan_loader constructs this from a blueprint book. Consumers use this API and
-- never need to know whether the plan came from a book, a GUI, or another
-- transport format.
local M = {}

local PlanMethods = {}
local SplitMethods = {}

local PlanMetatable = {
  __index = PlanMethods
}

local SplitMetatable = {
  __index = SplitMethods
}

local function sorted_names(map)
  local names = {}
  for name in pairs(map) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

local function merged_counts(placement_counts, extra_counts)
  local merged = {}
  for name, count in pairs(placement_counts or {}) do
    merged[name] = count
  end
  for name, count in pairs(extra_counts or {}) do
    merged[name] = (merged[name] or 0) + count
  end
  return merged
end

local function new_split(source)
  local production_item_counts = merged_counts(source.placement_item_counts, source.extra_item_counts)
  local split = {
    label = source.label,
    source_page_index = source.source_page_index,
    placement_item_counts = source.placement_item_counts,
    extra_item_counts = source.extra_item_counts,
    production_item_counts = production_item_counts,
    research_technologies = source.research_technologies,
    placement_item_names = sorted_names(source.placement_item_counts),
    extra_item_names = sorted_names(source.extra_item_counts),
    production_item_names = sorted_names(production_item_counts),
    research_technology_names = sorted_names(source.research_technologies)
  }
  return setmetatable(split, SplitMetatable)
end

function M.new(label, split_sources)
  local splits = {}
  local split_names = {}

  for index, source in ipairs(split_sources) do
    local split = new_split(source)
    splits[index] = split
    split_names[index] = split.label
  end

  return setmetatable({
    label = label,
    split_names = split_names,
    splits = splits
  }, PlanMetatable)
end

function M.register_metatables(script_root)
  script_root.register_metatable("long-pole-speedrun-plan", PlanMetatable)
  script_root.register_metatable("long-pole-speedrun-plan-split", SplitMetatable)
end

function PlanMethods:split_count()
  return #self.splits
end

function PlanMethods:split_at(index)
  return self.splits[index]
end

function SplitMethods:placement_item_count(item_name)
  return self.placement_item_counts[item_name] or 0
end

-- The numbered page in the original plan book. This is a durable locator,
-- not a retained Factorio LuaObject.
function SplitMethods:source_page()
  return self.source_page_index
end

function SplitMethods:extra_item_count(item_name)
  return self.extra_item_counts[item_name] or 0
end

-- Blueprint placement plus extra stock. This is what the factory should make
-- while the previous split is being placed.
function SplitMethods:production_item_count(item_name)
  return self.production_item_counts[item_name] or 0
end

function SplitMethods:requires_research(technology_name)
  return self.research_technologies[technology_name] == true
end

return M
