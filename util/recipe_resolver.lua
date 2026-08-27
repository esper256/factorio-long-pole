-- Prototype lookup only. Observed playthrough recipe-ratio blending and other
-- selection policies must live behind a replaceable heuristic module, not here
-- (PRODUCT.md §4).
local config = require("build_requirements_config")

local M = {}

local ALLOWED_RECIPE_CATEGORIES_BY_SURFACE = config.allowed_recipe_categories_by_surface or {}
local RECIPE_RESULT_INDEX_CACHE = setmetatable({}, {__mode = "k"})
local RECIPE_SURFACE_MATCH_CACHE = setmetatable({}, {__mode = "k"})

local function try_index(root, key)
  if root == nil then
    return nil
  end

  local ok, value = pcall(function()
    return root[key]
  end)
  if ok then
    return value
  end

  return nil
end

function M.get_recipe_prototypes()
  local runtime_recipe_prototypes = try_index(prototypes, "recipe")
  if runtime_recipe_prototypes then
    return runtime_recipe_prototypes
  end

  return try_index(game, "recipe_prototypes") or {}
end

function M.get_surface_properties(surface_name)
  local space_age_surfaces = try_index(game, "planets")
  local runtime_surface_location = space_age_surfaces and try_index(space_age_surfaces, surface_name)
  local runtime_surface_location_prototype = runtime_surface_location and try_index(runtime_surface_location, "prototype")
  local runtime_surface_location_properties = runtime_surface_location_prototype and try_index(runtime_surface_location_prototype, "surface_properties")
  if runtime_surface_location_properties then
    return runtime_surface_location_properties
  end

  local runtime_surface_prototypes = try_index(prototypes, "surface")
  local runtime_surface_prototype = runtime_surface_prototypes and try_index(runtime_surface_prototypes, surface_name)
  local runtime_surface_properties = runtime_surface_prototype and try_index(runtime_surface_prototype, "surface_properties")
  if runtime_surface_properties then
    return runtime_surface_properties
  end

  local runtime_space_locations = try_index(prototypes, "space_location")
  local runtime_space_location = runtime_space_locations and try_index(runtime_space_locations, surface_name)
  local runtime_space_location_properties = runtime_space_location and try_index(runtime_space_location, "surface_properties")
  if runtime_space_location_properties then
    return runtime_space_location_properties
  end

  return {}
end

function M.recipe_matches_surface_conditions(recipe, surface_name)
  local surface_conditions = try_index(recipe, "surface_conditions") or {}
  if #surface_conditions == 0 then
    return true
  end

  local surface_properties = M.get_surface_properties(surface_name)
  for _, condition in ipairs(surface_conditions) do
    local property_name = condition.property
    local property_value = surface_properties[property_name]
    if property_value == nil then
      return false
    end

    if condition.min and property_value < condition.min then
      return false
    end

    if condition.max and property_value > condition.max then
      return false
    end
  end

  return true
end

function M.recipe_category_allowed_on_surface(recipe, surface_name)
  local allowed_categories = ALLOWED_RECIPE_CATEGORIES_BY_SURFACE[surface_name] or {}
  local categories = {}
  local primary_category = try_index(recipe, "category") or "crafting"
  categories[#categories + 1] = primary_category

  -- Some 2.0/Space Age recipes expose alternate valid machine categories here,
  -- so callers should accept any allowed category, not just the primary.
  for _, category_name in ipairs(try_index(recipe, "additional_categories") or {}) do
    categories[#categories + 1] = category_name
  end

  for _, category_name in ipairs(categories) do
    if allowed_categories[category_name] == true then
      return true
    end
  end

  return false
end

function M.product_amount_for_result(recipe, kind, name)
  local products = try_index(recipe, "products") or {}
  for _, product in ipairs(products) do
    local product_kind = product.type or "item"
    if product_kind == kind and product.name == name then
      local amount = product.amount
      if not amount then
        local minimum = product.amount_min or 0
        local maximum = product.amount_max or minimum
        amount = (minimum + maximum) / 2
      end

      if product.probability then
        amount = amount * product.probability
      end

      if amount and amount > 0 then
        return amount
      end
    end
  end

  return nil
end

local function format_result_key(kind, name)
  return ("%s:%s"):format(kind or "item", name or "")
end

local function build_recipe_result_index(recipe_prototypes)
  local index = {}

  for _, recipe in pairs(recipe_prototypes or {}) do
    local seen_result_keys = {}
    local products = try_index(recipe, "products") or {}
    for _, product in ipairs(products) do
      local result_key = format_result_key(product.type or "item", product.name)
      if not seen_result_keys[result_key] then
        seen_result_keys[result_key] = true
        index[result_key] = index[result_key] or {}
        index[result_key][#index[result_key] + 1] = recipe
      end
    end
  end

  return index
end

local function get_recipe_result_index(recipe_prototypes)
  local resolved_recipe_prototypes = recipe_prototypes or M.get_recipe_prototypes()
  local cached_index = RECIPE_RESULT_INDEX_CACHE[resolved_recipe_prototypes]
  if cached_index then
    return cached_index, resolved_recipe_prototypes
  end

  local built_index = build_recipe_result_index(resolved_recipe_prototypes)
  RECIPE_RESULT_INDEX_CACHE[resolved_recipe_prototypes] = built_index
  RECIPE_SURFACE_MATCH_CACHE[resolved_recipe_prototypes] = {}
  return built_index, resolved_recipe_prototypes
end

function M.find_recipes_for_result(kind, name, surface_name, recipe_prototypes)
  local resolved_surface_name = surface_name or "nauvis"
  local result_key = format_result_key(kind, name)
  local recipe_index, resolved_recipe_prototypes = get_recipe_result_index(recipe_prototypes)
  local surface_cache = RECIPE_SURFACE_MATCH_CACHE[resolved_recipe_prototypes]
  surface_cache[result_key] = surface_cache[result_key] or {}

  local cached_matches = surface_cache[result_key][resolved_surface_name]
  if cached_matches then
    return cached_matches
  end

  local matches = {}
  for _, recipe in ipairs(recipe_index[result_key] or {}) do
    if M.recipe_category_allowed_on_surface(recipe, resolved_surface_name)
      and M.recipe_matches_surface_conditions(recipe, resolved_surface_name) then
      matches[#matches + 1] = recipe
    end
  end

  surface_cache[result_key][resolved_surface_name] = matches
  return matches
end

function M.clear_caches()
  for recipe_prototypes in pairs(RECIPE_RESULT_INDEX_CACHE) do
    RECIPE_RESULT_INDEX_CACHE[recipe_prototypes] = nil
  end
  for recipe_prototypes in pairs(RECIPE_SURFACE_MATCH_CACHE) do
    RECIPE_SURFACE_MATCH_CACHE[recipe_prototypes] = nil
  end
end

function M.get_cache_stats()
  local prototype_set_count = 0
  local indexed_result_count = 0

  for _, index in pairs(RECIPE_RESULT_INDEX_CACHE) do
    prototype_set_count = prototype_set_count + 1
    for _ in pairs(index) do
      indexed_result_count = indexed_result_count + 1
    end
  end

  return {
    prototype_set_count = prototype_set_count,
    indexed_result_count = indexed_result_count
  }
end

return M
