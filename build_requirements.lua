local M = {}
local config = require("build_requirements_config")
local recipe_resolver = require("util.recipe_resolver")

local RAW_RESOURCES_BY_SURFACE = config.raw_resources_by_surface or {}
local HIDDEN_RAW_RESOURCES_BY_SURFACE = config.hidden_raw_resources_by_surface or {}
local IGNORED_REQUIREMENT_KEYS = config.ignored_requirement_keys or {}

-- This module turns split definitions plus runtime stock snapshots into the
-- planning views the UI needs: direct progress, missing intermediates, and raw
-- resource cost. Most of the complexity is about preserving split semantics
-- while staying conservative around recipe ambiguity.

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

local function copy_counts(source)
  local copied = {}
  for key, value in pairs(source or {}) do
    copied[key] = value
  end
  return copied
end

local function format_requirement_key(kind, name)
  return ("%s:%s"):format(kind or "unknown", name or "unknown")
end

local function get_technology_prototypes()
  local runtime_technology_prototypes = try_index(prototypes, "technology")
  if runtime_technology_prototypes then
    return runtime_technology_prototypes
  end

  return try_index(game, "technology_prototypes") or {}
end

local function ingredient_kind(ingredient)
  return ingredient.type or "item"
end

local function ingredient_amount(ingredient)
  return ingredient.amount or ingredient.count or 0
end

local function is_ignored_requirement(kind, name)
  return IGNORED_REQUIREMENT_KEYS[kind .. ":" .. name] == true
end

local function is_raw_resource(kind, name, surface_name)
  local surface_resources = RAW_RESOURCES_BY_SURFACE[surface_name] or RAW_RESOURCES_BY_SURFACE.nauvis or {}
  return surface_resources[kind .. ":" .. name] == true
end

local function is_hidden_raw_resource(kind, name, surface_name)
  local hidden_resources = HIDDEN_RAW_RESOURCES_BY_SURFACE[surface_name] or {}
  return hidden_resources[kind .. ":" .. name] == true
end

local function score_totals(totals)
  local score = 0
  for _, entry in pairs(totals or {}) do
    -- Prefer production paths that bottom out in true raw resources. Penalizing
    -- manufactured intermediates keeps raw-cost expansion from "solving" a plate
    -- by recursively requiring another processed item instead of ore.
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

local function resolve_raw_cost_entry(kind, name, surface_name, resolve_recipe_set, cache, active_stack)
  local entry_key = surface_name .. ":" .. kind .. ":" .. name
  if cache[entry_key] then
    return cache[entry_key], nil
  end

  if is_ignored_requirement(kind, name) then
    local ignored_totals = {}
    cache[entry_key] = ignored_totals
    return ignored_totals, nil
  end

  if active_stack[entry_key] then
    -- Cycles show up with modded recipes and would recurse forever otherwise.
    return nil, ("Detected a recipe cycle while resolving %s on %s."):format(
      format_requirement_key(kind, name),
      surface_name
    )
  end

  if is_raw_resource(kind, name, surface_name) then
    local raw_totals = {}
    add_total(raw_totals, kind, name, 1)
    cache[entry_key] = raw_totals
    return raw_totals, nil
  end

  active_stack[entry_key] = true
  local matching_recipes = resolve_recipe_set(kind, name, surface_name) or {}
  local best_totals = nil
  local best_score = nil

  for _, recipe in ipairs(matching_recipes) do
    local product_amount = recipe_resolver.product_amount_for_result(recipe, kind, name)
    if product_amount and product_amount > 0 then
      local candidate_totals = {}
      for _, ingredient in ipairs(recipe.ingredients or {}) do
        local ingredient_totals, error_message = resolve_raw_cost_entry(
          ingredient_kind(ingredient),
          ingredient.name,
          surface_name,
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
      if best_score == nil or candidate_score < best_score then
        best_totals = candidate_totals
        best_score = candidate_score
      end
    end
  end

  active_stack[entry_key] = nil

  if not best_totals then
    return nil, ("Could not resolve a valid production path for %s on %s."):format(
      format_requirement_key(kind, name),
      surface_name
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

local function add_root_requirement(root_requirements, kind, name, count, satisfaction_mode)
  if is_ignored_requirement(kind, name) or not (count and count > 0) then
    return
  end

  local key = ("%s:%s"):format(satisfaction_mode or "loose_only", format_requirement_key(kind, name))
  local entry = root_requirements[key]
  if not entry then
    entry = {
      kind = kind,
      name = name,
      count = 0,
      satisfaction_mode = satisfaction_mode or "loose_only"
    }
    root_requirements[key] = entry
  end

  entry.count = entry.count + count
end

local function build_root_requirements(split, options)
  local resolve_entity_components = options.resolve_entity_components or M.resolve_entity_place_items
  local technology_prototypes = options.technology_prototypes or get_technology_prototypes()
  local resolve_technology_components = options.resolve_technology_components or function(technology_name)
    return M.resolve_technology_requirements(technology_name, technology_prototypes)
  end
  local root_requirements = {}
  local include_blueprints = options.include_blueprints ~= false
  local include_items = options.include_items ~= false
  local include_technologies = options.include_technologies ~= false
  local blueprint_satisfaction_mode = options.blueprint_satisfaction_mode or "placed_or_loose"
  local item_satisfaction_mode = options.item_satisfaction_mode or "loose_only"
  local technology_satisfaction_mode = options.technology_satisfaction_mode or "loose_only"

  -- Satisfaction modes are what preserve split semantics downstream:
  -- blueprints can require placed entities, stock goals only consume loose
  -- items, and research currently behaves like a stock goal for science packs.
  if include_blueprints then
    for _, blueprint in ipairs(split.blueprints or {}) do
      for _, entry in ipairs(blueprint.entity_summary or {}) do
        local components = resolve_entity_components(entry.name) or fallback_entity_component(entry.name)
        for _, component in ipairs(components) do
          add_root_requirement(
            root_requirements,
            component.kind or "item",
            component.name,
            (component.count or 1) * (entry.count or 0),
            blueprint_satisfaction_mode
          )
        end
      end
    end
  end

  if include_items then
    for _, item in ipairs(split.items or {}) do
      if item.name and item.name ~= "" then
        add_root_requirement(root_requirements, "item", item.name, item.count or 0, item_satisfaction_mode)
      end
    end
  end

  if include_technologies then
    for _, technology in ipairs(split.technologies or {}) do
      if technology.name and technology.name ~= "" then
        -- Research completion is not tracked per split yet, so we only count loose
        -- packs here until a split-scoped research progress source exists.
        for _, component in ipairs(resolve_technology_components(technology.name)) do
          add_root_requirement(
            root_requirements,
            component.kind or "item",
            component.name,
            component.count or 0,
            technology_satisfaction_mode
          )
        end
      end
    end
  end

  local entries = {}
  for _, entry in pairs(root_requirements) do
    entries[#entries + 1] = entry
  end

  table.sort(entries, function(a, b)
    if a.kind == b.kind then
      if a.name == b.name then
        return a.satisfaction_mode < b.satisfaction_mode
      end
      return a.name < b.name
    end
    return a.kind < b.kind
  end)

  return entries
end

function M.build_root_requirements(split, options)
  return build_root_requirements(split, options or {})
end

local function build_requirement_pools(snapshot)
  local pools = {
    stock_by_key = {},
    placed_by_key = {}
  }

  -- `current_split_claim` intentionally only reserves placements already
  -- credited to this split, so previous split entities do not satisfy a new
  -- placement goal just because they happen to use the same item.
  for _, entry in ipairs(snapshot and snapshot.entries or {}) do
    local key = format_requirement_key("item", entry.item_name)
    pools.stock_by_key[key] = tonumber(entry.loose_stock) or 0
    pools.placed_by_key[key] = math.max(0, tonumber(entry.current_split_claim) or 0)
  end

  return pools
end

local function add_progress_entry(entries_by_key, kind, name, required_delta, fulfilled_delta)
  if is_ignored_requirement(kind, name) then
    return
  end

  local key = format_requirement_key(kind, name)
  local entry = entries_by_key[key]
  if not entry then
    entry = {
      kind = kind,
      name = name,
      required_count = 0,
      fulfilled_count = 0
    }
    entries_by_key[key] = entry
  end

  entry.required_count = entry.required_count + (required_delta or 0)
  entry.fulfilled_count = entry.fulfilled_count + (fulfilled_delta or 0)
end

local function merge_progress_entries(target, source)
  for _, entry in pairs(source or {}) do
    add_progress_entry(target, entry.kind, entry.name, entry.required_count, entry.fulfilled_count)
  end
end

local function reserve_from_pool(pool, key, count)
  local available = pool[key] or 0
  if available <= 0 or count <= 0 then
    return 0
  end

  local reserved = math.min(available, count)
  pool[key] = available - reserved
  return reserved
end

local function reserve_direct_requirement(pools, kind, name, count, satisfaction_mode)
  local key = format_requirement_key(kind, name)
  local reserved = 0

  if satisfaction_mode == "placed_only" then
    return reserve_from_pool(pools.placed_by_key, key, count)
  end

  if satisfaction_mode == "placed_or_loose" then
    -- When a requirement can be satisfied by already-placed entities, consume
    -- those claims before loose stock so the next-split readiness view does not
    -- incorrectly treat them as carry-over inventory.
    reserved = reserved + reserve_from_pool(pools.placed_by_key, key, count)
    reserved = reserved + reserve_from_pool(pools.stock_by_key, key, count - reserved)
    return reserved
  end

  return reserve_from_pool(pools.stock_by_key, key, count)
end

local function batch_count_for_requirement(required_count, product_amount)
  if not (required_count and required_count > 0 and product_amount and product_amount > 0) then
    return 0
  end

  return math.ceil((required_count / product_amount) - 0.0000001)
end

local function missing_score(entries_by_key)
  local score = 0
  for _, entry in pairs(entries_by_key or {}) do
    score = score + math.max(0, (entry.required_count or 0) - (entry.fulfilled_count or 0))
  end
  return score
end

local function requirement_progress_to_summary(entries_by_key)
  local summary = {}
  for _, entry in pairs(entries_by_key or {}) do
    local required_count = entry.required_count or 0
    local fulfilled_count = math.min(required_count, entry.fulfilled_count or 0)
    local missing_count = math.max(0, required_count - fulfilled_count)
    if missing_count > 0 then
      summary[#summary + 1] = {
        kind = entry.kind,
        name = entry.name,
        count = missing_count,
        required_count = required_count,
        fulfilled_count = fulfilled_count,
        progress = required_count > 0 and (fulfilled_count / required_count) or 1,
        sprite = ("%s/%s"):format(entry.kind, entry.name)
      }
    end
  end

  table.sort(summary, function(a, b)
    if a.count == b.count then
      if a.progress == b.progress then
        if a.kind == b.kind then
          return a.name < b.name
        end
        return a.kind < b.kind
      end
      return a.progress < b.progress
    end
    return a.count > b.count
  end)

  return summary
end

local function choose_recipe_for_missing_requirement(kind, name, remaining_count, context, active_stack)
  local matching_recipes = context.resolve_recipe_set(kind, name, context.surface_name) or {}
  local best_candidate = nil
  local first_error_message = nil

  for _, recipe in ipairs(matching_recipes) do
    local product_amount = recipe_resolver.product_amount_for_result(recipe, kind, name)
    local batch_count = batch_count_for_requirement(remaining_count, product_amount)
    if batch_count > 0 then
      local candidate_context = {
        surface_name = context.surface_name,
        resolve_recipe_set = context.resolve_recipe_set,
        pools = {
          stock_by_key = copy_counts(context.pools.stock_by_key),
          placed_by_key = copy_counts(context.pools.placed_by_key)
        },
        progress_entries_by_key = {}
      }
      -- Candidate recipes are evaluated against cloned pools so a losing branch
      -- cannot consume stock needed by the winning branch.
      local error_message = nil

      for _, ingredient in ipairs(recipe.ingredients or {}) do
        error_message = M.plan_missing_requirement(
          ingredient_kind(ingredient),
          ingredient.name,
          ingredient_amount(ingredient) * batch_count,
          "loose_only",
          candidate_context,
          active_stack
        )
        if error_message then
          first_error_message = first_error_message or error_message
          break
        end
      end

      if not error_message then
        local candidate_score = missing_score(candidate_context.progress_entries_by_key)
        local recipe_name = recipe.name or ""
        local best_recipe_name = best_candidate and (best_candidate.recipe.name or "") or ""
        if not best_candidate
          or candidate_score < best_candidate.score
          or (candidate_score == best_candidate.score and recipe_name < best_recipe_name) then
          best_candidate = {
            recipe = recipe,
            score = candidate_score,
            pools = candidate_context.pools,
            progress_entries_by_key = candidate_context.progress_entries_by_key
          }
        end
      end
    end
  end

  return best_candidate, first_error_message
end

function M.plan_missing_requirement(kind, name, count, satisfaction_mode, context, active_stack)
  if is_ignored_requirement(kind, name) or not (kind and name and count and count > 0) then
    return nil
  end

  add_progress_entry(context.progress_entries_by_key, kind, name, count, 0)

  local fulfilled_count = reserve_direct_requirement(context.pools, kind, name, count, satisfaction_mode)
  if fulfilled_count > 0 then
    add_progress_entry(context.progress_entries_by_key, kind, name, 0, fulfilled_count)
  end

  local remaining_count = count - fulfilled_count
  if remaining_count <= 0 then
    return nil
  end

  local entry_key = context.surface_name .. ":" .. format_requirement_key(kind, name)
  if active_stack[entry_key] then
    return ("Detected a recipe cycle while resolving %s on %s."):format(
      format_requirement_key(kind, name),
      context.surface_name
    )
  end

  active_stack[entry_key] = true
  local best_candidate, error_message = choose_recipe_for_missing_requirement(
    kind,
    name,
    remaining_count,
    context,
    active_stack
  )
  active_stack[entry_key] = nil

  if best_candidate then
    context.pools = best_candidate.pools
    merge_progress_entries(context.progress_entries_by_key, best_candidate.progress_entries_by_key)
    return nil
  end

  return error_message
end

local function build_context(snapshot, options)
  local initial_pools = options.initial_pools or build_requirement_pools(snapshot)

  return {
    surface_name = options.surface_name,
    resolve_recipe_set = options.resolve_recipe_set,
    pools = {
      stock_by_key = copy_counts(initial_pools.stock_by_key),
      placed_by_key = copy_counts(initial_pools.placed_by_key)
    },
    progress_entries_by_key = {}
  }
end

function M.summarize_direct_requirement_progress(split, snapshot, options)
  options = options or {}

  local surface_name = split.surface or options.surface_name or "nauvis"
  local context = build_context(snapshot, {
    surface_name = surface_name,
    resolve_recipe_set = options.resolve_recipe_set,
    initial_pools = options.initial_pools
  })
  local root_requirements = options.root_requirements or build_root_requirements(split, options)

  for _, requirement in ipairs(root_requirements) do
    add_progress_entry(
      context.progress_entries_by_key,
      requirement.kind,
      requirement.name,
      requirement.count,
      0
    )

    local fulfilled_count = reserve_direct_requirement(
      context.pools,
      requirement.kind,
      requirement.name,
      requirement.count,
      requirement.satisfaction_mode
    )
    if fulfilled_count > 0 then
      add_progress_entry(
        context.progress_entries_by_key,
        requirement.kind,
        requirement.name,
        0,
        fulfilled_count
      )
    end
  end

  return requirement_progress_to_summary(context.progress_entries_by_key), nil, context.pools
end

function M.summarize_missing_requirements(split, snapshot, options)
  options = options or {}

  local surface_name = split.surface or options.surface_name or "nauvis"
  local recipe_prototypes = options.recipe_prototypes or recipe_resolver.get_recipe_prototypes()
  local context = build_context(snapshot, {
    surface_name = surface_name,
    resolve_recipe_set = options.resolve_recipe_set or function(kind, name, resolved_surface_name)
      return recipe_resolver.find_recipes_for_result(kind, name, resolved_surface_name, recipe_prototypes)
    end,
    initial_pools = options.initial_pools
  })
  local root_requirements = options.root_requirements or build_root_requirements(split, options)
  local first_error_message = nil

  for _, requirement in ipairs(root_requirements) do
    local error_message = M.plan_missing_requirement(
      requirement.kind,
      requirement.name,
      requirement.count,
      requirement.satisfaction_mode,
      context,
      {}
    )
    first_error_message = first_error_message or error_message
  end

  -- Keep the best partial summary even if one branch cannot be resolved. That
  -- lets the UI stay informative instead of collapsing to a single fatal error.
  return requirement_progress_to_summary(context.progress_entries_by_key), first_error_message, context.pools
end

function M.find_recipes_for_result(kind, name, surface_name, recipe_prototypes)
  return recipe_resolver.find_recipes_for_result(kind, name, surface_name, recipe_prototypes)
end

function M.summarize_raw_cost(split, options)
  options = options or {}

  local surface_name = split.surface or options.surface_name or "nauvis"
  local combined_totals = {}
  for _, entry in ipairs(M.summarize_split(split, {
    resolve_entity_components = options.resolve_entity_components,
    resolve_technology_components = options.resolve_technology_components,
    technology_prototypes = options.technology_prototypes
  })) do
    add_total(combined_totals, entry.kind, entry.name, entry.count)
  end

  local recipe_prototypes = options.recipe_prototypes or recipe_resolver.get_recipe_prototypes()
  local resolve_recipe_set = options.resolve_recipe_set or function(kind, name, resolved_surface_name)
    return recipe_resolver.find_recipes_for_result(kind, name, resolved_surface_name, recipe_prototypes)
  end

  local raw_totals = {}
  local cache = {}
  for _, entry in pairs(combined_totals) do
    local ingredient_totals, error_message = resolve_raw_cost_entry(
      entry.kind,
      entry.name,
      surface_name,
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
    if not is_hidden_raw_resource(entry.kind, entry.name, surface_name) then
      add_total(filtered_totals, entry.kind, entry.name, entry.count)
    end
  end

  return totals_to_summary(filtered_totals), nil
end

return M
