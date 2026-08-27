-- Replaceable recipe-selection policy (PRODUCT.md §4).
-- Callers pass candidate recipes plus optional observed craft ratios.
-- This module must stay the only place that decides "which recipe" or "how to
-- blend recipes". build_requirements should not hard-code oil/recycling trees.

local recipe_resolver = require("util.recipe_resolver")

local M = {}

local function recipe_name(recipe)
  return (recipe and recipe.name) or ""
end

local function missing_score(entries_by_key)
  local score = 0
  for _, entry in pairs(entries_by_key or {}) do
    score = score + math.max(0, (entry.required_count or 0) - (entry.fulfilled_count or 0))
  end
  return score
end

function M.normalize_ratios(matching_recipes, recipe_ratios)
  local selected = {}
  local total_weight = 0

  for _, recipe in ipairs(matching_recipes or {}) do
    local name = recipe_name(recipe)
    local weight = recipe_ratios and tonumber(recipe_ratios[name]) or nil
    if weight and weight > 0 then
      selected[#selected + 1] = {
        recipe = recipe,
        weight = weight
      }
      total_weight = total_weight + weight
    end
  end

  if total_weight <= 0 or #selected == 0 then
    return nil
  end

  for _, entry in ipairs(selected) do
    entry.weight = entry.weight / total_weight
  end

  return selected
end

local function merge_progress(target, source)
  for key, entry in pairs(source or {}) do
    local existing = target[key]
    if not existing then
      target[key] = {
        kind = entry.kind,
        name = entry.name,
        required_count = entry.required_count or 0,
        fulfilled_count = entry.fulfilled_count or 0
      }
    else
      existing.required_count = (existing.required_count or 0) + (entry.required_count or 0)
      existing.fulfilled_count = (existing.fulfilled_count or 0) + (entry.fulfilled_count or 0)
    end
  end
end

-- plan_recipe_fn(recipe, amount) -> { score, pools, progress_entries_by_key } or nil, error
function M.choose_recipe(matching_recipes, context, remaining_count, plan_recipe_fn)
  if type(remaining_count) == "function" then
    plan_recipe_fn = remaining_count
    remaining_count = nil
  end

  remaining_count = tonumber(remaining_count) or 0
  local ratios = context and context.recipe_ratios or nil
  local blended = M.normalize_ratios(matching_recipes, ratios)

  if blended and #blended > 0 and remaining_count > 0 then
    local merged_progress = {}
    local last_pools = context and context.pools or nil
    local first_error = nil
    local any = false

    for _, entry in ipairs(blended) do
      local amount = remaining_count * entry.weight
      if amount > 0 then
        local candidate, error_message = plan_recipe_fn(entry.recipe, amount, last_pools)
        first_error = first_error or error_message
        if candidate then
          any = true
          last_pools = candidate.pools or last_pools
          merge_progress(merged_progress, candidate.progress_entries_by_key)
        end
      end
    end

    if any then
      return {
        recipe = blended[1].recipe,
        score = missing_score(merged_progress),
        pools = last_pools,
        progress_entries_by_key = merged_progress
      }
    end
    return nil, first_error
  end

  local best_candidate = nil
  local first_error_message = nil
  local amount = remaining_count > 0 and remaining_count or nil

  for _, recipe in ipairs(matching_recipes or {}) do
    local candidate, error_message = plan_recipe_fn(recipe, amount)
    first_error_message = first_error_message or error_message
    if candidate then
      local name = recipe_name(recipe)
      local best_name = best_candidate and recipe_name(best_candidate.recipe) or ""
      local score = candidate.score or missing_score(candidate.progress_entries_by_key)
      candidate.score = score
      candidate.recipe = recipe
      if not best_candidate
        or score < best_candidate.score
        or (score == best_candidate.score and name < best_name) then
        best_candidate = candidate
      end
    end
  end

  return best_candidate, first_error_message
end

function M.handcraft_rate_per_minute(kind, name, recipe)
  if not recipe then
    return 0
  end

  local energy = tonumber(recipe.energy) or 0.5
  if energy <= 0 then
    energy = 0.5
  end

  local amount = recipe_resolver.product_amount_for_result(recipe, kind, name) or 1
  return (60 / energy) * amount
end

function M.score_entries(entries_by_key)
  return missing_score(entries_by_key)
end

return M
