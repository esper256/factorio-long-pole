local M = {}
local config = require("build_requirements_config")

local RAW_RESOURCES_BY_PLANET = config.raw_resources_by_planet or {}
local HIDDEN_RAW_RESOURCES_BY_PLANET = config.hidden_raw_resources_by_planet or {}
local ALLOWED_RECIPE_CATEGORIES_BY_PLANET = config.allowed_recipe_categories_by_planet or {}
local IGNORED_REQUIREMENT_KEYS = config.ignored_requirement_keys or {}
local DEBUG_RECIPE_TRACE_KEYS = {
  ["item:transport-belt"] = true
}

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

local function add_total(totals, kind, name, count)
  if not (kind and name and count and count > 0) then
    return
  end

  local key = kind .. ":" .. name
  local entry = totals[key]
  if not entry then
    entry = {
      kind = kind,
      name = name,
      count = 0
    }
    totals[key] = entry
  end

  entry.count = entry.count + count
end

local function merge_totals(target, source, multiplier)
  for _, entry in pairs(source or {}) do
    add_total(target, entry.kind, entry.name, (entry.count or 0) * (multiplier or 1))
  end
end

local function totals_to_summary(totals)
  local summary = {}
  for _, entry in pairs(totals) do
    summary[#summary + 1] = {
      kind = entry.kind,
      name = entry.name,
      count = entry.count,
      sprite = ("%s/%s"):format(entry.kind, entry.name)
    }
  end

  table.sort(summary, function(a, b)
    if a.count == b.count then
      if a.kind == b.kind then
        return a.name < b.name
      end
      return a.kind < b.kind
    end
    return a.count > b.count
  end)

  return summary
end

local function format_requirement_key(kind, name)
  return ("%s:%s"):format(kind or "unknown", name or "unknown")
end

local function should_debug_requirement(kind, name)
  return DEBUG_RECIPE_TRACE_KEYS[format_requirement_key(kind, name)] == true
end

local function debug_log_requirement(kind, name, message)
  if not should_debug_requirement(kind, name) then
    return
  end

  if type(log) ~= "function" then
    return
  end

  log(("[long-pole][raw-cost][%s] %s"):format(format_requirement_key(kind, name), message))
end

local function get_recipe_prototypes()
  local runtime_recipe_prototypes = try_index(prototypes, "recipe")
  if runtime_recipe_prototypes then
    return runtime_recipe_prototypes
  end

  return try_index(game, "recipe_prototypes") or {}
end

local function get_technology_prototypes()
  local runtime_technology_prototypes = try_index(prototypes, "technology")
  if runtime_technology_prototypes then
    return runtime_technology_prototypes
  end

  return try_index(game, "technology_prototypes") or {}
end

local function get_surface_properties_for_planet(planet_name)
  local planets = try_index(game, "planets")
  local runtime_planet = planets and try_index(planets, planet_name)
  local runtime_planet_prototype = runtime_planet and try_index(runtime_planet, "prototype")
  local runtime_planet_properties = runtime_planet_prototype and try_index(runtime_planet_prototype, "surface_properties")
  if runtime_planet_properties then
    return runtime_planet_properties
  end

  local runtime_surface_prototypes = try_index(prototypes, "surface")
  local runtime_surface_prototype = runtime_surface_prototypes and try_index(runtime_surface_prototypes, planet_name)
  local runtime_surface_properties = runtime_surface_prototype and try_index(runtime_surface_prototype, "surface_properties")
  if runtime_surface_properties then
    return runtime_surface_properties
  end

  local runtime_space_locations = try_index(prototypes, "space_location")
  local runtime_space_location = runtime_space_locations and try_index(runtime_space_locations, planet_name)
  local runtime_space_location_properties = runtime_space_location and try_index(runtime_space_location, "surface_properties")
  if runtime_space_location_properties then
    return runtime_space_location_properties
  end

  return {}
end

local function recipe_matches_surface_conditions(recipe, planet_name)
  local surface_conditions = try_index(recipe, "surface_conditions") or {}
  if #surface_conditions == 0 then
    return true
  end

  local surface_properties = get_surface_properties_for_planet(planet_name)
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

local function recipe_category_allowed_on_planet(recipe, planet_name)
  local allowed_categories = ALLOWED_RECIPE_CATEGORIES_BY_PLANET[planet_name] or {}
  local categories = {}
  local primary_category = try_index(recipe, "category") or "crafting"
  categories[#categories + 1] = primary_category

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

local function recipe_category_debug_string(recipe)
  local primary_category = try_index(recipe, "category") or "crafting"
  local additional_categories = try_index(recipe, "additional_categories") or {}
  if #additional_categories == 0 then
    return primary_category
  end

  return ("%s (+ %s)"):format(primary_category, table.concat(additional_categories, ", "))
end

local function product_amount_for_target(recipe, kind, name)
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

local function ingredient_kind(ingredient)
  return ingredient.type or "item"
end

local function is_ignored_requirement(kind, name)
  return IGNORED_REQUIREMENT_KEYS[kind .. ":" .. name] == true
end

local function is_raw_resource(kind, name, planet_name)
  local planet_resources = RAW_RESOURCES_BY_PLANET[planet_name] or RAW_RESOURCES_BY_PLANET.nauvis or {}
  return planet_resources[kind .. ":" .. name] == true
end

local function is_hidden_raw_resource(kind, name, planet_name)
  local hidden_resources = HIDDEN_RAW_RESOURCES_BY_PLANET[planet_name] or {}
  return hidden_resources[kind .. ":" .. name] == true
end

local function score_totals(totals)
  local score = 0
  for _, entry in pairs(totals or {}) do
    if is_raw_resource(entry.kind, entry.name, "nauvis")
      or is_raw_resource(entry.kind, entry.name, "vulcanus")
      or is_raw_resource(entry.kind, entry.name, "fulgora")
      or is_raw_resource(entry.kind, entry.name, "gleba")
      or is_raw_resource(entry.kind, entry.name, "aquilo") then
      score = score + (entry.count or 0)
    else
      score = score + 1000000 + (entry.count or 0)
    end
  end
  return score
end

local function resolve_raw_cost_entry(kind, name, planet_name, resolve_recipe_set, cache, active_stack)
  local entry_key = planet_name .. ":" .. kind .. ":" .. name
  if cache[entry_key] then
    debug_log_requirement(kind, name, ("cache hit on %s"):format(planet_name))
    return cache[entry_key], nil
  end

  if is_ignored_requirement(kind, name) then
    local ignored_totals = {}
    cache[entry_key] = ignored_totals
    return ignored_totals, nil
  end

  if active_stack[entry_key] then
    return nil, ("Detected a recipe cycle while resolving %s on %s."):format(
      format_requirement_key(kind, name),
      planet_name
    )
  end

  if is_raw_resource(kind, name, planet_name) then
    local raw_totals = {}
    add_total(raw_totals, kind, name, 1)
    cache[entry_key] = raw_totals
    debug_log_requirement(kind, name, ("treated as raw resource on %s"):format(planet_name))
    return raw_totals, nil
  end

  active_stack[entry_key] = true
  local matching_recipes = resolve_recipe_set(kind, name, planet_name) or {}
  debug_log_requirement(kind, name, ("candidate recipes on %s: %d"):format(planet_name, #matching_recipes))
  local best_totals = nil
  local best_score = nil

  for _, recipe in ipairs(matching_recipes) do
    debug_log_requirement(kind, name, ("trying recipe %s with categories %s"):format(
      try_index(recipe, "name") or "<unnamed>",
      recipe_category_debug_string(recipe)
    ))
    local product_amount = product_amount_for_target(recipe, kind, name)
    if product_amount and product_amount > 0 then
      local candidate_totals = {}
      for _, ingredient in ipairs(recipe.ingredients or {}) do
        local ingredient_totals, error_message = resolve_raw_cost_entry(
          ingredient_kind(ingredient),
          ingredient.name,
          planet_name,
          resolve_recipe_set,
          cache,
          active_stack
        )
        if error_message then
          active_stack[entry_key] = nil
          return nil, error_message
        end
        merge_totals(candidate_totals, ingredient_totals, (ingredient.amount or 0) / product_amount)
      end

      local candidate_score = score_totals(candidate_totals)
      debug_log_requirement(kind, name, ("recipe %s produced candidate score %s"):format(
        try_index(recipe, "name") or "<unnamed>",
        tostring(candidate_score)
      ))
      if best_score == nil or candidate_score < best_score then
        best_totals = candidate_totals
        best_score = candidate_score
        debug_log_requirement(kind, name, ("recipe %s is new best candidate"):format(
          try_index(recipe, "name") or "<unnamed>"
        ))
      end
    end
  end

  active_stack[entry_key] = nil

  if not best_totals then
    debug_log_requirement(kind, name, ("no valid production path found on %s"):format(planet_name))
    return nil, ("Could not resolve a valid production path for %s on %s."):format(
      format_requirement_key(kind, name),
      planet_name
    )
  end

  cache[entry_key] = best_totals
  return best_totals, nil
end

local function fallback_entity_component(entity_name)
  return {
    {
      kind = "entity",
      name = entity_name,
      count = 1
    }
  }
end

local function normalize_summarize_options(options_or_resolver)
  if type(options_or_resolver) == "function" then
    return {
      resolve_entity_components = options_or_resolver
    }
  end

  return options_or_resolver or {}
end

local function get_entity_prototype(entity_name)
  local runtime_entity_prototypes = try_index(prototypes, "entity")
  local runtime_prototype = try_index(runtime_entity_prototypes, entity_name)
  if runtime_prototype then
    return runtime_prototype
  end

  -- Older examples often reference game.entity_prototypes. Keep this as a
  -- guarded fallback so tests or tooling can still provide it safely.
  local legacy_entity_prototypes = try_index(game, "entity_prototypes")
  return try_index(legacy_entity_prototypes, entity_name)
end

function M.resolve_entity_place_items(entity_name)
  local prototype = get_entity_prototype(entity_name)
  if not prototype then
    return fallback_entity_component(entity_name)
  end

  local items = try_index(prototype, "items_to_place_this") or {}
  if #items == 0 then
    return fallback_entity_component(entity_name)
  end

  local resolved = {}
  for _, item in ipairs(items) do
    resolved[#resolved + 1] = {
      kind = "item",
      name = item.name,
      count = item.count or 1
    }
  end

  return resolved
end

function M.resolve_technology_requirements(technology_name, technology_prototypes)
  local prototype = try_index(technology_prototypes or get_technology_prototypes(), technology_name)
  if not prototype then
    return {}
  end

  local research_unit_count = try_index(prototype, "research_unit_count") or 0
  local research_ingredients = try_index(prototype, "research_unit_ingredients") or {}
  if research_unit_count <= 0 or #research_ingredients == 0 then
    return {}
  end

  local totals = {}
  for _, ingredient in ipairs(research_ingredients) do
    add_total(
      totals,
      "item",
      ingredient.name,
      (ingredient.amount or ingredient.count or 0) * research_unit_count
    )
  end

  return totals_to_summary(totals)
end

function M.summarize_split(split, options_or_resolver)
  local options = normalize_summarize_options(options_or_resolver)
  local resolve_entity_components = options.resolve_entity_components or M.resolve_entity_place_items
  local technology_prototypes = options.technology_prototypes or get_technology_prototypes()
  local resolve_technology_components = options.resolve_technology_components or function(technology_name)
    return M.resolve_technology_requirements(technology_name, technology_prototypes)
  end
  local totals = {}

  for _, blueprint in ipairs(split.blueprints or {}) do
    for _, entry in ipairs(blueprint.entity_summary or {}) do
      local components = resolve_entity_components(entry.name) or fallback_entity_component(entry.name)
      for _, component in ipairs(components) do
        add_total(
          totals,
          component.kind or "item",
          component.name,
          (component.count or 1) * (entry.count or 0)
        )
      end
    end
  end

  for _, item in ipairs(split.items or {}) do
    if item.name and item.name ~= "" then
      add_total(totals, "item", item.name, item.count or 0)
    end
  end

  for _, technology in ipairs(split.technologies or {}) do
    if technology.name and technology.name ~= "" then
      merge_totals(totals, resolve_technology_components(technology.name))
    end
  end

  return totals_to_summary(totals)
end

function M.find_recipes_for_result(kind, name, planet_name, recipe_prototypes)
  local matches = {}
  for _, recipe in pairs(recipe_prototypes or get_recipe_prototypes()) do
    local products = try_index(recipe, "products") or {}
    for _, product in ipairs(products) do
      if (product.type or "item") == kind and product.name == name then
        local resolved_planet_name = planet_name or "nauvis"
        local category_allowed = recipe_category_allowed_on_planet(recipe, resolved_planet_name)
        local surface_allowed = recipe_matches_surface_conditions(recipe, resolved_planet_name)

        if should_debug_requirement(kind, name) then
          debug_log_requirement(kind, name, ("recipe %s categories=%s allowed=%s surface_ok=%s"):format(
            try_index(recipe, "name") or "<unnamed>",
            recipe_category_debug_string(recipe),
            tostring(category_allowed),
            tostring(surface_allowed)
          ))
        end

        if category_allowed and surface_allowed then
          matches[#matches + 1] = recipe
        end
        break
      end
    end
  end

  return matches
end

function M.summarize_raw_cost(split, options)
  options = options or {}

  local planet_name = split.planet or options.planet_name or "nauvis"
  local combined_totals = {}
  for _, entry in ipairs(M.summarize_split(split, {
    resolve_entity_components = options.resolve_entity_components,
    resolve_technology_components = options.resolve_technology_components,
    technology_prototypes = options.technology_prototypes
  })) do
    add_total(combined_totals, entry.kind, entry.name, entry.count)
  end

  local recipe_prototypes = options.recipe_prototypes or get_recipe_prototypes()
  local resolve_recipe_set = options.resolve_recipe_set or function(kind, name, resolved_planet_name)
    return M.find_recipes_for_result(kind, name, resolved_planet_name, recipe_prototypes)
  end

  local raw_totals = {}
  local cache = {}
  for _, entry in pairs(combined_totals) do
    local ingredient_totals, error_message = resolve_raw_cost_entry(
      entry.kind,
      entry.name,
      planet_name,
      resolve_recipe_set,
      cache,
      {}
    )
    if error_message then
      return {}, error_message
    end
    merge_totals(raw_totals, ingredient_totals, entry.count)
  end

  local filtered_totals = {}
  for _, entry in pairs(raw_totals) do
    if not is_hidden_raw_resource(entry.kind, entry.name, planet_name) then
      add_total(filtered_totals, entry.kind, entry.name, entry.count)
    end
  end

  return totals_to_summary(filtered_totals), nil
end

return M
