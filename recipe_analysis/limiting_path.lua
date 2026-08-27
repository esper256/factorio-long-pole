-- Walk a product's recipe chain toward root blockers (PRODUCT.md §3).
-- If gears are missing and plates are in stock, the blocker is gears.
-- If plates are also missing, the blocker is plates.
local resolver = require("recipe_resolution.resolver")
local heuristic = require("recipe_resolution.heuristic")
local eta = require("progress_analysis.eta")

local M = {}

local function recipe_energy(recipe)
  return recipe.energy or 0.5
end

local function handcraft_rate(recipe, context)
  return eta.handcraft_per_minute(recipe_energy(recipe), context.crafting_speed)
end

local function finish_ticks_for(item_name, remaining, context)
  local recipes = resolver.recipes_producing(item_name)
  local hand = eta.handcraft_per_minute(0.5, context.crafting_speed)
  if recipes[1] then
    hand = handcraft_rate(recipes[1], context)
  end
  return eta.finish_ticks(
    remaining,
    context.produced_per_minute(item_name),
    hand
  )
end

local function merge_blocker(blockers_by_name, blocker)
  local existing = blockers_by_name[blocker.item_name]
  if not existing then
    blockers_by_name[blocker.item_name] = {
      item_name = blocker.item_name,
      count = blocker.count,
      eta_ticks = blocker.eta_ticks
    }
    return
  end
  existing.count = existing.count + blocker.count
  existing.eta_ticks = math.max(existing.eta_ticks, blocker.eta_ticks)
end

local function walk(item_name, remaining, context, depth, blockers_by_name)
  remaining = math.max(0, remaining or 0)
  if remaining <= 0 or depth > 8 then
    return
  end

  local recipes = resolver.recipes_producing(item_name)
  local choices = heuristic.choose(recipes, context.observed_crafts)
  if #choices == 0 then
    merge_blocker(blockers_by_name, {
      item_name = item_name,
      count = remaining,
      eta_ticks = finish_ticks_for(item_name, remaining, context)
    })
    return
  end

  local ingredient_shortfall = false
  for _, choice in ipairs(choices) do
    local product_amount = resolver.product_amount(choice.recipe, item_name)
    if product_amount <= 0 then
      product_amount = 1
    end
    local batches = remaining * choice.weight / product_amount
    for _, ingredient in ipairs(choice.recipe.ingredients or {}) do
      if ingredient.type ~= "fluid" then
        local need = batches * (ingredient.amount or 0)
        local have = context.loose_stock(ingredient.name)
        local still = need - have
        if still > 0 then
          ingredient_shortfall = true
          walk(ingredient.name, still, context, depth + 1, blockers_by_name)
        end
      end
    end
  end

  if not ingredient_shortfall then
    merge_blocker(blockers_by_name, {
      item_name = item_name,
      count = remaining,
      eta_ticks = finish_ticks_for(item_name, remaining, context)
    })
  end
end

function M.blockers(item_name, remaining, context)
  local blockers_by_name = {}
  walk(item_name, remaining, context, 1, blockers_by_name)
  local blockers = {}
  for _, blocker in pairs(blockers_by_name) do
    blockers[#blockers + 1] = blocker
  end
  return blockers
end

return M
