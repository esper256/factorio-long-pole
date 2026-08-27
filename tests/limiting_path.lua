-- PRODUCT.md §3: surface the limiting ingredient, not the unfinished good,
-- when an intermediate is the real blocker.
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

local limiting_path = require("recipe_analysis.limiting_path")

local function context_with(stock)
  return {
    crafting_speed = 1,
    produced_per_minute = function()
      return 0
    end,
    loose_stock = function(item_name)
      return stock[item_name] or 0
    end
  }
end

local function names(blockers)
  local found = {}
  for _, blocker in ipairs(blockers) do
    found[blocker.item_name] = blocker.count
  end
  return found
end

local gears_limited = names(limiting_path.blockers(
  "transport-belt",
  1000,
  context_with({ ["iron-plate"] = 10000 })
))
assert(gears_limited["iron-gear-wheel"] == 500)
assert(gears_limited["transport-belt"] == nil)
assert(gears_limited["iron-plate"] == nil)

local plates_limited = names(limiting_path.blockers(
  "transport-belt",
  1000,
  context_with({})
))
assert(plates_limited["iron-plate"] ~= nil)
assert(plates_limited["iron-plate"] > 0)
assert(plates_limited["transport-belt"] == nil)
assert(plates_limited["iron-gear-wheel"] == nil)
