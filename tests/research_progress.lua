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
local nauvis = game_state.surface(state, "nauvis")
nauvis:record_products_produced({
  ["automation-science-pack"] = 3,
  ["logistic-science-pack"] = 5
})
game_state.set_research(state, "automation", false, 0.5)
game_state.set_research(state, "logistics", true)

local force = {
  technologies = {
    automation = {
      research_unit_count = 10,
      research_unit_ingredients = {
        { name = "automation-science-pack", amount = 1 }
      }
    },
    logistics = {
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
assert(progress.pending == 3)
assert(progress.tooltip == "Research: 25 complete · 3 science ready · 2 remaining")
assert(progress.unfinished_items[1].item_name == "automation-science-pack")
assert(progress.unfinished_items[1].count == 2)

game_state.set_research(state, "automation", false, 0.91)
local in_flight_progress = research_progress.for_split(plan:split_at(1), state, force)
assert(in_flight_progress.done == 29.1)
assert(math.abs(in_flight_progress.pending - 0.9) < 0.000001)
assert(#in_flight_progress.unfinished_items == 0)
