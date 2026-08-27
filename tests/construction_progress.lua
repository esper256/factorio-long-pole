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
nauvis:record_products_produced({ ["stone-furnace"] = 15, rail = 6 })
nauvis:record_products_placed({ ["stone-furnace"] = 10, rail = 3 })

local split = plan:split_at(1)
local snapshot = { ["stone-furnace"] = 9, rail = 2 }
local progress = construction_progress.for_split(split, state, snapshot)

assert(progress.total == 10)
assert(progress.done == 2)
assert(progress.pending == 6)
assert(progress.tooltip == "Construction: 2 placed · 6 ready to place · 2 remaining")
assert(progress.unfinished_items[1].item_name == "rail")
assert(progress.unfinished_items[1].count == 2)

prototypes = {
  recipe = {
    ["iron-gear-wheel"] = {
      name = "iron-gear-wheel",
      energy = 0.5,
      categories = { "crafting" },
      products = { { name = "iron-gear-wheel", amount = 1 } },
      ingredients = { { type = "item", name = "iron-plate", amount = 2 } }
    },
    ["transport-belt"] = {
      name = "transport-belt",
      energy = 0.5,
      categories = { "crafting" },
      products = { { name = "transport-belt", amount = 2 } },
      ingredients = {
        { type = "item", name = "iron-plate", amount = 1 },
        { type = "item", name = "iron-gear-wheel", amount = 1 }
      }
    }
  }
}

local belt_plan = speedrun_plan.new("Practice [LP]", {
  {
    label = "Belts",
    placement_item_counts = { ["transport-belt"] = 10 },
    extra_item_counts = {},
    research_technologies = {}
  }
})
local belt_state = game_state.new()
game_state.surface(belt_state, "nauvis"):record_products_produced({ ["iron-plate"] = 10000 })
local belt_progress = construction_progress.for_split(
  belt_plan:split_at(1),
  belt_state,
  {}
)
assert(belt_progress.unfinished_items[1].item_name == "iron-gear-wheel")
assert(belt_progress.unfinished_items[1].count == 5)
assert(belt_progress.unfinished_items[1].item_name ~= "transport-belt")
for _, item in ipairs(belt_progress.unfinished_items) do
  assert(item.item_name ~= "transport-belt")
end
