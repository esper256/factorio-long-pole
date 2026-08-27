local recipe_heuristic = require("util.recipe_heuristic")

describe("recipe_heuristic", function()
  it("picks the lower remaining-ingredient recipe when no ratios are provided", function()
    local recipes = {
      {
        name = "basic",
        ingredients = {},
        products = {{type = "item", name = "oil", amount = 1}}
      },
      {
        name = "advanced",
        ingredients = {},
        products = {{type = "item", name = "oil", amount = 1}}
      }
    }

    local chosen = recipe_heuristic.choose_recipe(recipes, {}, 10, function(recipe, amount)
      local score = recipe.name == "basic" and 8 or 3
      return {
        recipe = recipe,
        score = score,
        pools = {},
        progress_entries_by_key = {
          coal = {
            kind = "item",
            name = "coal",
            required_count = score,
            fulfilled_count = 0
          }
        }
      }, nil
    end)

    assert.are.equal("advanced", chosen.recipe.name)
    assert.are.equal(3, chosen.score)
  end)

  it("blends observed recipe ratios instead of picking a single tree", function()
    local recipes = {
      {name = "basic-oil-processing"},
      {name = "advanced-oil-processing"}
    }
    local planned = {}
    local chosen = recipe_heuristic.choose_recipe(recipes, {
      recipe_ratios = {
        ["basic-oil-processing"] = 1,
        ["advanced-oil-processing"] = 1
      },
      pools = {}
    }, 10, function(recipe, amount)
      planned[#planned + 1] = {
        name = recipe.name,
        amount = amount
      }
      return {
        recipe = recipe,
        score = amount,
        pools = {},
        progress_entries_by_key = {
          [recipe.name] = {
            kind = "item",
            name = recipe.name,
            required_count = amount,
            fulfilled_count = 0
          }
        }
      }
    end)

    assert.are.equal(2, #planned)
    assert.are.equal(5, planned[1].amount)
    assert.are.equal(5, planned[2].amount)
    assert.are.equal(10, chosen.score)
  end)
end)
