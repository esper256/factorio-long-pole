local heuristic = require("recipe_resolution.heuristic")
local resolver = require("recipe_resolution.resolver")

local basic = { name = "basic-oil-processing" }
local advanced = { name = "advanced-oil-processing" }

local none = heuristic.choose({})
assert(#none == 0)

local first = heuristic.choose({ basic, advanced })
assert(#first == 1)
assert(first[1].recipe == basic)
assert(first[1].weight == 1)

local blended = heuristic.choose(
  { basic, advanced },
  { ["basic-oil-processing"] = 1, ["advanced-oil-processing"] = 3 }
)
assert(#blended == 2)
assert(blended[1].recipe == basic)
assert(blended[1].weight == 0.25)
assert(blended[2].recipe == advanced)
assert(blended[2].weight == 0.75)

assert(resolver.recipe_categories({
  categories = { "crafting", "crafting-with-fluid" }
})[2] == "crafting-with-fluid")
assert(resolver.recipe_categories({
  category = "crafting",
  additional_categories = { "organic" }
})[2] == "organic")
assert(resolver.recipe_categories({})[1] == "crafting")
assert(resolver.product_amount({
  products = { { name = "iron-gear-wheel", amount = 1 } }
}, "iron-gear-wheel") == 1)
assert(resolver.product_amount({
  products = { { name = "petroleum-gas", amount_min = 2, amount_max = 4 } }
}, "petroleum-gas") == 3)
