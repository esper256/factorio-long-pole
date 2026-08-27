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
    extra_item_counts = {},
    research_technologies = {}
  }
})
local state = game_state.new()
local nauvis = game_state.surface(state, "nauvis")
nauvis:record_products_produced({
  ["stone-furnace"] = 8,
  rail = 5,
  ["transport-belt"] = 1
})
nauvis:record_products_placed({ ["stone-furnace"] = 1 })

local progress = next_split_construction_progress.for_splits(
  plan:split_at(1),
  plan:split_at(2),
  state,
  { ["stone-furnace"] = 0, rail = 0 }
)

assert(progress.total == 11)
assert(progress.done == 0)
assert(progress.pending == 7)
assert(progress.tooltip == "Next construction: 7 ready to place · 4 remaining")
assert(progress.unfinished_items[1].item_name == "rail")
assert(progress.unfinished_items[1].count == 2)
assert(progress.unfinished_items[2].item_name == "stone-furnace")
assert(progress.unfinished_items[2].count == 1)
