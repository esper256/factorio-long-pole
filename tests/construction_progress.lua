local construction_progress = require("progress_analysis.construction_progress")
local game_state = require("game_state.game_state")
local speedrun_plan = require("speedrun_plan.plan")

local plan = speedrun_plan.new("Practice [LP]", {
  {
    label = "Build",
    placement_item_counts = {
      ["stone-furnace"] = 4,
      rail = 6
    },
    extra_item_counts = {},
    research_technologies = {}
  }
})
local state = game_state.new()
local nauvis = game_state.surface(state, "nauvis")
nauvis:record_products_produced({ ["stone-furnace"] = 15, rail = 13 })
nauvis:record_products_placed({ ["stone-furnace"] = 10, rail = 3 })

local split = plan:split_at(1)
local snapshot = { ["stone-furnace"] = 9, rail = 2 }
local progress = construction_progress.for_split(split, state, snapshot)

assert(progress.total == 10)
assert(progress.done == 2)
assert(progress.pending == 8)
assert(progress.tooltip == "Construction: 2 placed · 8 ready to place · 0 remaining")
