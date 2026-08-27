local extra_item_progress = require("progress_analysis.extra_item_progress")
local game_state = require("game_state.game_state")
local speedrun_plan = require("speedrun_plan.plan")

local plan = speedrun_plan.new("Practice [LP]", {
  {
    label = "Coal run",
    placement_item_counts = {},
    extra_item_counts = {
      coal = 50,
      wood = 10
    },
    research_technologies = {}
  }
})
local state = game_state.new()
local nauvis = game_state.surface(state, "nauvis")
nauvis:record_products_harvested({ coal = 35, wood = 12 })

local progress = extra_item_progress.for_split(plan:split_at(1), state)
assert(progress.total == 60)
assert(progress.done == 45)
assert(progress.pending == 0)
assert(progress.tooltip == "Extra items: 45 ready · 15 remaining")
assert(progress.unfinished_items[1].item_name == "coal")
assert(progress.unfinished_items[1].count == 15)
