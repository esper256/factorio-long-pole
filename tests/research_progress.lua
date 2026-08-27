local game_state = require("game_state.game_state")
local research_progress = require("progress_analysis.research_progress")
local speedrun_plan = require("speedrun_plan.plan")

local plan = speedrun_plan.new("Practice [LP]", {
  {
    label = "Research",
    placement_item_counts = {},
    extra_item_counts = {},
    research_technologies = {
      automation = true,
      logistics = true
    }
  }
})
local state = game_state.new()
game_state.set_lab_throughput(state, 2)

local force = {
  current_research = { name = "automation" },
  research_progress = 0.5,
  technologies = {
    automation = {
      researched = false,
      saved_progress = 0.1,
      research_unit_count = 10,
      research_unit_ingredients = {
        { name = "automation-science-pack", amount = 1 }
      }
    },
    logistics = {
      researched = true,
      saved_progress = 0,
      research_unit_count = 10,
      research_unit_ingredients = {
        { name = "automation-science-pack", amount = 1 },
        { name = "logistic-science-pack", amount = 1 }
      }
    }
  }
}

local progress = research_progress.for_split(plan:split_at(1), state, force)
assert(progress.total == 30)
assert(progress.done == 25)
assert(progress.pending == 0)
assert(progress.working_labs == 2)
assert(progress.unfinished_items[1].item_name == "automation-science-pack")
assert(progress.unfinished_items[1].count == 5)
assert(progress.tooltip == "Research: 25 consumed in labs · 5 remaining · 2 labs working")

force.research_progress = 0.91
local in_flight_progress = research_progress.for_split(plan:split_at(1), state, force)
assert(in_flight_progress.done == 29.1)
assert(#in_flight_progress.unfinished_items == 1)
assert(math.abs(in_flight_progress.unfinished_items[1].count - 0.9) < 0.000001)
