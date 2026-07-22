-- A speedrun attempt owns only mutable run state while retaining the parsed
-- plan object it is attempting to execute.
local speedrun_attempt = require("speedrun_plan.attempt")
local speedrun_plan = require("speedrun_plan.plan")
local speedrun_attempts = require("runtime_state.speedrun_attempts")

storage = {}

local plan = speedrun_plan.new("Nauvis practice [LP]", {
  {
    label = "Burner phase",
    entity_counts = { ["stone-furnace"] = 1 },
    extra_item_counts = { coal = 10 },
    research_technologies = {}
  },
  {
    label = "Automation",
    entity_counts = { lab = 1 },
    extra_item_counts = {},
    research_technologies = { automation = true }
  }
})

local attempt = speedrun_attempt.new(plan, 4)

local initial_view = attempt:hud_view(120)
assert(initial_view.plan_label == "Nauvis practice [LP]")
assert(initial_view.current_split_label == "Burner phase")
assert(initial_view.next_split_label == "Automation")
assert(initial_view.previous_split_label == nil)
assert(initial_view.library_book_index == 4)

attempt:mark_current_split_done(3600)

local advanced_view = attempt:hud_view(3660)
assert(advanced_view.previous_split_label == "Burner phase")
assert(advanced_view.previous_split_finished_tick == 3600)
assert(advanced_view.current_split_label == "Automation")
assert(advanced_view.next_split_label == nil)

local stored_attempt = speedrun_attempts.start(1, plan, 4)
assert(stored_attempt.plan == plan)
assert(speedrun_attempts.get(1).plan == plan)
