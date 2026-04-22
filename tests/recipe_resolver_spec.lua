local recipe_resolver = require("util.recipe_resolver")

describe("recipe_resolver", function()
  local original_game
  local original_prototypes

  before_each(function()
    original_game = rawget(_G, "game")
    original_prototypes = rawget(_G, "prototypes")
    _G.game = nil
    _G.prototypes = nil
    if recipe_resolver.clear_caches then
      recipe_resolver.clear_caches()
    end
  end)

  after_each(function()
    _G.game = original_game
    _G.prototypes = original_prototypes
    if recipe_resolver.clear_caches then
      recipe_resolver.clear_caches()
    end
  end)

  it("filters recipes by surface conditions", function()
    _G.prototypes = {
      recipe = {
        ["steam-on-nauvis"] = {
          products = {
            {type = "item", name = "steam-core", amount = 1}
          },
          surface_conditions = {
            {property = "pressure", min = 900, max = 1100}
          }
        },
        ["steam-on-vulcanus"] = {
          products = {
            {type = "item", name = "steam-core", amount = 1}
          },
          surface_conditions = {
            {property = "pressure", min = 3500, max = 4500}
          }
        }
      },
      surface = {
        nauvis = {
          surface_properties = {
            pressure = 1000
          }
        },
        vulcanus = {
          surface_properties = {
            pressure = 4000
          }
        }
      }
    }

    local nauvis_matches = recipe_resolver.find_recipes_for_result("item", "steam-core", "nauvis")
    local vulcanus_matches = recipe_resolver.find_recipes_for_result("item", "steam-core", "vulcanus")

    assert.are.equal(1, #nauvis_matches)
    assert.are.equal(1, #vulcanus_matches)
    assert.same(_G.prototypes.recipe["steam-on-nauvis"], nauvis_matches[1])
    assert.same(_G.prototypes.recipe["steam-on-vulcanus"], vulcanus_matches[1])
  end)

  it("accepts recipes when an allowed category appears in additional_categories", function()
    _G.prototypes = {
      recipe = {
        ["transport-belt"] = {
          category = "crushing",
          additional_categories = {"metallurgy-or-assembling"},
          products = {
            {type = "item", name = "transport-belt", amount = 2}
          }
        }
      }
    }

    local matches = recipe_resolver.find_recipes_for_result("item", "transport-belt", "nauvis")

    assert.are.equal(1, #matches)
    assert.same(_G.prototypes.recipe["transport-belt"], matches[1])
  end)

  it("calculates expected output amount for probabilistic products", function()
    local amount = recipe_resolver.product_amount_for_result({
      products = {
        {type = "item", name = "processing-unit", amount_min = 1, amount_max = 3, probability = 0.5}
      }
    }, "item", "processing-unit")

    assert.are.equal(1, amount)
  end)

end)
