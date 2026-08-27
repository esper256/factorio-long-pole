-- Arrival-time estimates for remaining work (PRODUCT.md §1, §2).
-- Factory rate plus a hypothetical nonstop handcraft of that item, so
-- zero-rate crafts stay sortable instead of tying at infinity.

local recipe_heuristic = require("util.recipe_heuristic")

local M = {}

local MINIMUM_ITEMS_PER_MINUTE = 1

local function is_science_pack(name, pack_rates)
  if not name then
    return false
  end
  if pack_rates and pack_rates[name] ~= nil then
    return true
  end
  return name:find("science%-pack", 1, false) ~= nil
end

local function choose_handcraft_recipe(kind, name, surface_name, resolve_recipe_set)
  if not resolve_recipe_set then
    return nil
  end

  local recipes = resolve_recipe_set(kind, name, surface_name) or {}
  local best = nil
  local best_rate = nil
  for _, recipe in ipairs(recipes) do
    local rate = recipe_heuristic.handcraft_rate_per_minute(kind, name, recipe)
    if best_rate == nil or rate > best_rate then
      best = recipe
      best_rate = rate
    end
  end
  return best
end

function M.eta_seconds_for_entry(entry, snapshot, options)
  local remaining = math.max(0, tonumber(entry and entry.count) or 0)
  if remaining <= 0 then
    return 0
  end

  local produced_rate = 0
  local consumed_rate = 0
  local pack_rates = snapshot and snapshot.research and snapshot.research.pack_consumption_per_minute or {}

  if entry.kind == "item" then
    for _, stock_entry in ipairs(snapshot and snapshot.entries or {}) do
      if stock_entry.item_name == entry.name then
        produced_rate = tonumber(stock_entry.produced_rate) or 0
        consumed_rate = tonumber(stock_entry.consumed_rate) or 0
        break
      end
    end
    if pack_rates[entry.name] then
      consumed_rate = math.max(consumed_rate, tonumber(pack_rates[entry.name]) or 0)
    end
  end

  if is_science_pack(entry.name, pack_rates) then
    if consumed_rate > 0 then
      return remaining / (consumed_rate / 60)
    end
    return math.huge
  end

  local handcraft_recipe = choose_handcraft_recipe(
    entry.kind,
    entry.name,
    options and options.surface_name or "nauvis",
    options and options.resolve_recipe_set
  )
  local handcraft_rate = recipe_heuristic.handcraft_rate_per_minute(entry.kind, entry.name, handcraft_recipe)
  local combined = produced_rate + handcraft_rate
  if combined <= 0 then
    combined = MINIMUM_ITEMS_PER_MINUTE
  end

  return remaining / (combined / 60)
end

function M.attach(entries, snapshot, options)
  for _, entry in ipairs(entries or {}) do
    entry.eta_seconds = M.eta_seconds_for_entry(entry, snapshot, options)
  end
  return entries
end

function M.format_seconds(eta_seconds)
  if eta_seconds == nil then
    return nil
  end
  if eta_seconds == math.huge or eta_seconds ~= eta_seconds then
    return "no rate"
  end

  local total_seconds = math.max(0, math.floor(eta_seconds + 0.5))
  local hours = math.floor(total_seconds / 3600)
  local minutes = math.floor((total_seconds % 3600) / 60)
  local seconds = total_seconds % 60
  if hours > 0 then
    return ("%d:%02d:%02d"):format(hours, minutes, seconds)
  end
  return ("%d:%02d"):format(minutes, seconds)
end

return M
