-- Prototype lookup for recipes that can make a product. 2.1 recipes expose
-- `categories`; older shapes used `category` plus `additional_categories`.
local M = {}

function M.recipe_categories(recipe)
  if recipe.categories then
    return recipe.categories
  end
  local categories = {}
  if recipe.category then
    categories[#categories + 1] = recipe.category
  end
  if recipe.additional_categories then
    for _, category in ipairs(recipe.additional_categories) do
      categories[#categories + 1] = category
    end
  end
  if #categories == 0 then
    categories[1] = "crafting"
  end
  return categories
end

function M.product_amount(recipe, product_name)
  for _, product in ipairs(recipe.products or {}) do
    if product.name == product_name then
      return product.amount or ((product.amount_min or 0) + (product.amount_max or 0)) / 2
    end
  end
  return 0
end

function M.recipes_producing(product_name)
  local recipes = {}
  if not (prototypes and prototypes.recipe) then
    return recipes
  end
  for _, recipe in pairs(prototypes.recipe) do
    if M.product_amount(recipe, product_name) > 0 then
      recipes[#recipes + 1] = recipe
    end
  end
  table.sort(recipes, function(left, right)
    return (left.name or "") < (right.name or "")
  end)
  return recipes
end

return M
