local next_split_construction_progress = require("progress_analysis.next_split_construction_progress")
local game_state = require("game_state.game_state")
local speedrun_plan = require("speedrun_plan.plan")

local plan = speedrun_plan.new("Practice [LP]", {
  {
    label = "Current build",
    placement_item_counts = {
      ["stone-furnace"] = 4,
      rail = 3
    },
    extra_item_counts = {},
    research_technologies = {}
  },
  {
    label = "Next build",
    placement_item_counts = {
      ["stone-furnace"] = 5,
      rail = 4,
      ["transport-belt"] = 2
    },
    extra_item_counts = {
      coal = 50
    },
    research_technologies = {}
  }
})
local state = game_state.new()
local nauvis = game_state.surface(state, "nauvis")
nauvis:record_products_produced({
  ["stone-furnace"] = 8,
  rail = 5,
  ["transport-belt"] = 1,
  coal = 10
})
nauvis:record_products_placed({ ["stone-furnace"] = 1 })

assert(plan:split_at(2):production_item_count("coal") == 50)
assert(plan:split_at(2):production_item_count("stone-furnace") == 5)

local progress = next_split_construction_progress.for_splits(
  plan:split_at(1),
  plan:split_at(2),
  state,
  { ["stone-furnace"] = 0, rail = 0 }
)

assert(progress.total == 61)
assert(progress.done == 0)
assert(progress.pending == 17)
assert(progress.tooltip == "Next production: 17 ready · 44 remaining")
assert(progress.unfinished_items[1].item_name == "coal")
assert(progress.unfinished_items[1].count == 40)
