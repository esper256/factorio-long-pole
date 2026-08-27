-- From test_data/speedrun_plan_blueprint.txt, page "Copper Hand Smelter":
-- 2 stone furnaces, extra copper-ore 12, lab 1, automation-science-pack 10.
-- 15 mined copper-ore must not finish that copper demand: extra ore, red
-- packs, and the lab each used to claim the same 15.
prototypes = {
  recipe = {
    ["copper-plate"] = {
      name = "copper-plate",
      energy = 3.2,
      categories = { "smelting" },
      products = { { name = "copper-plate", amount = 1 } },
      ingredients = { { type = "item", name = "copper-ore", amount = 1 } }
    },
    ["copper-cable"] = {
      name = "copper-cable",
      energy = 0.5,
      categories = { "crafting" },
      products = { { name = "copper-cable", amount = 2 } },
      ingredients = { { type = "item", name = "copper-plate", amount = 1 } }
    },
    ["electronic-circuit"] = {
      name = "electronic-circuit",
      energy = 0.5,
      categories = { "crafting" },
      products = { { name = "electronic-circuit", amount = 1 } },
      ingredients = {
        { type = "item", name = "iron-plate", amount = 1 },
        { type = "item", name = "copper-cable", amount = 3 }
      }
    },
    ["iron-plate"] = {
      name = "iron-plate",
      energy = 3.2,
      categories = { "smelting" },
      products = { { name = "iron-plate", amount = 1 } },
      ingredients = { { type = "item", name = "iron-ore", amount = 1 } }
    },
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
    },
    ["automation-science-pack"] = {
      name = "automation-science-pack",
      energy = 5,
      categories = { "crafting" },
      products = { { name = "automation-science-pack", amount = 1 } },
      ingredients = {
        { type = "item", name = "copper-plate", amount = 1 },
        { type = "item", name = "iron-gear-wheel", amount = 1 }
      }
    },
    lab = {
      name = "lab",
      energy = 2,
      categories = { "crafting" },
      products = { { name = "lab", amount = 1 } },
      ingredients = {
        { type = "item", name = "electronic-circuit", amount = 10 },
        { type = "item", name = "iron-gear-wheel", amount = 10 },
        { type = "item", name = "transport-belt", amount = 4 }
      }
    },
    ["stone-furnace"] = {
      name = "stone-furnace",
      energy = 0.5,
      categories = { "crafting" },
      products = { { name = "stone-furnace", amount = 1 } },
      ingredients = { { type = "item", name = "stone", amount = 5 } }
    }
  }
}

local next_split_construction_progress = require("progress_analysis.next_split_construction_progress")
local game_state = require("game_state.game_state")
local speedrun_plan = require("speedrun_plan.plan")

local plan = speedrun_plan.new("100% DS Speedrun [LP]", {
  {
    label = "Mine coal rocks",
    placement_item_counts = {},
    extra_item_counts = {},
    research_technologies = {}
  },
  {
    label = "Copper Hand Smelter",
    placement_item_counts = { ["stone-furnace"] = 2 },
    extra_item_counts = {
      ["copper-ore"] = 12,
      lab = 1,
      ["automation-science-pack"] = 10
    },
    research_technologies = {}
  }
})

local function copper_remaining(progress)
  local total = 0
  for _, item in ipairs(progress.unfinished_items) do
    if item.item_name == "copper-ore" or item.item_name == "copper-plate"
      or item.item_name == "copper-cable" then
      total = total + item.count
    end
  end
  return total
end

local empty_state = game_state.new()
local empty_progress = next_split_construction_progress.for_splits(
  plan:split_at(1),
  plan:split_at(2),
  empty_state,
  {}
)
assert(copper_remaining(empty_progress) >= 30)

local mined_state = game_state.new()
game_state.surface(mined_state, "nauvis"):record_products_produced({ ["copper-ore"] = 15 })
local mined_progress = next_split_construction_progress.for_splits(
  plan:split_at(1),
  plan:split_at(2),
  mined_state,
  {}
)
assert(copper_remaining(mined_progress) > 0)
assert(copper_remaining(mined_progress) >= 15)
assert(mined_progress.total - mined_progress.pending > 12)
