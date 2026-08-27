-- A speedrun attempt owns only mutable run state while retaining the parsed
-- plan object it is attempting to execute.
local speedrun_attempt = require("speedrun_plan.attempt")
local speedrun_plan = require("speedrun_plan.plan")
local speedrun_attempts = require("runtime_state.speedrun_attempts")
local game_state = require("game_state.game_state")

storage = {}

local plan = speedrun_plan.new("Nauvis practice [LP]", {
  {
    label = "Burner phase",
    placement_item_counts = { ["stone-furnace"] = 1 },
    extra_item_counts = { coal = 10 },
    research_technologies = {}
  },
  {
    label = "Automation",
    placement_item_counts = { lab = 1 },
    extra_item_counts = {},
    research_technologies = { automation = true }
  }
})

local state = game_state.new()
local nauvis = game_state.surface(state, "nauvis")
nauvis:record_products_placed({ ["stone-furnace"] = 6, lab = 2 })

local attempt = speedrun_attempt.new(plan, 4, state)

local initial_view = attempt:hud_view(120)
assert(initial_view.plan_label == "Nauvis practice [LP]")
assert(initial_view.current_split_label == "Burner phase")
assert(initial_view.next_split_label == "Automation")
assert(initial_view.previous_split_label == nil)
assert(initial_view.library_book_index == 4)
assert(attempt.split_start_placed_product_counts["stone-furnace"] == 6)

attempt:mark_current_split_done(3600, state)

local advanced_view = attempt:hud_view(3660)
assert(advanced_view.previous_split_label == "Burner phase")
assert(advanced_view.previous_split_finished_tick == 3600)
assert(advanced_view.current_split_label == "Automation")
assert(advanced_view.next_split_label == nil)
assert(attempt.split_start_placed_product_counts.lab == 2)
assert(attempt.split_finished_ticks[1] == 3600)

assert(attempt:rewind_split(3700, state) == true)
local rewound_view = attempt:hud_view(3700)
assert(rewound_view.current_split_label == "Burner phase")
assert(rewound_view.next_split_label == "Automation")
assert(rewound_view.previous_split_label == nil)
assert(attempt.current_split_index == 1)
assert(attempt.split_finished_ticks[1] == nil)
assert(attempt.split_start_placed_product_counts["stone-furnace"] == 6)
assert(attempt:rewind_split(3700, state) == false)

attempt:mark_current_split_done(3600, state)
local stored_attempt = speedrun_attempts.start(1, plan, 4)
assert(stored_attempt.plan == plan)
assert(speedrun_attempts.get(1).plan == plan)
