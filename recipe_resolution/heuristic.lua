-- Replaceable recipe-selection policy (PRODUCT.md §4).
-- Callers pass candidate recipes plus optional observed craft counts.
-- This is the only module that may decide "which recipe" or how to blend.
local M = {}

local function recipe_name(recipe)
  return (recipe and recipe.name) or ""
end

-- Returns { { recipe = recipe, weight = 0..1 }, ... } summing to 1 when
-- non-empty. Observed craft counts blend; otherwise the first sorted recipe
-- takes the whole weight so callers stay deterministic.
function M.choose(recipes, observed_crafts)
  if not recipes or #recipes == 0 then
    return {}
  end

  local total = 0
  local weights = {}
  for _, recipe in ipairs(recipes) do
    local count = (observed_crafts and observed_crafts[recipe_name(recipe)]) or 0
    weights[recipe] = count
    total = total + count
  end

  local blended = {}
  if total <= 0 then
    blended[1] = { recipe = recipes[1], weight = 1 }
    return blended
  end

  for _, recipe in ipairs(recipes) do
    local weight = weights[recipe] / total
    if weight > 0 then
      blended[#blended + 1] = { recipe = recipe, weight = weight }
    end
  end
  return blended
end

return M
