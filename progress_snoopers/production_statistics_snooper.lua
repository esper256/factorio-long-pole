local progress_tracker_store = require("progress_tracker_store")
local safe_index = require("util.safe_index")

local M = {
  id = "production-statistics"
}

-- Factorio's item production statistics are the best broad "automated factory flow"
-- signal the runtime API exposes, but they are not a perfect machine-IO ledger.
--
-- Known limitations in current Factorio 2.0.x behavior:
-- - The statistics are cumulative per-surface force totals, not stock snapshots, and
--   they are not scoped per machine or recipe.
-- - Hand crafting contributes produced items to the production totals without giving us
--   equally trustworthy ingredient consumption there, so hand-crafted outputs are
--   excluded through the hand-crafting snooper before we apply stat deltas.
-- - Manual mining of resource entities is also reflected as production, so those mined
--   outputs are excluded through the mined-entity snooper to avoid double counting.
-- - Loot-like results such as rocks, trees, and similar entity drops are not reliably
--   represented in the production statistics, so those still depend on direct events.
-- - Consumption is recorded when the game records it in the statistics; if the game
--   later returns ingredients because a craft is aborted, the statistics themselves do
--   not provide an undo signal we can reconcile perfectly from polling alone.

local function try_index(root, key)
  return safe_index.get(root, key)
end

local function relevant_force_names(state, runtime)
  local names = {}
  local players = try_index(runtime, "players") or {}
  for _, player in pairs(players) do
    local force = try_index(player, "force")
    local force_name = try_index(force, "name")
    if force_name then
      names[force_name] = force
    end
  end

  if next(names) ~= nil then
    return names
  end

  for _, force in pairs(try_index(runtime, "forces") or {}) do
    local force_name = try_index(force, "name")
    if force_name and force_name ~= "enemy" and force_name ~= "neutral" then
      names[force_name] = force
    end
  end

  return names
end

local function relevant_surface_names(state, runtime)
  local names = {}
  for _, split in ipairs(state and state.splits or {}) do
    if split.surface and split.surface ~= "" then
      names[split.surface] = true
    end
  end

  local players = try_index(runtime, "players") or {}
  for _, player in pairs(players) do
    local surface = try_index(player, "surface")
    local surface_name = try_index(surface, "name")
    if surface_name then
      names[surface_name] = true
    end
  end

  if next(names) ~= nil then
    return names
  end

  for _, surface in pairs(try_index(runtime, "surfaces") or {}) do
    local surface_name = try_index(surface, "name")
    if surface_name then
      names[surface_name] = true
    end
  end

  return names
end

function M.poll(state, runtime)
  local runtime_root = runtime or rawget(_G, "game")
  if not runtime_root then
    return false
  end

  local handled = false
  local forces = relevant_force_names(state, runtime_root)
  local surface_names = relevant_surface_names(state, runtime_root)
  local surfaces = try_index(runtime_root, "surfaces") or {}

  for force_name, force in pairs(forces) do
    if force and force.get_item_production_statistics then
      for _, surface in pairs(surfaces) do
        local surface_name = try_index(surface, "name")
        if surface_name and surface_names[surface_name] then
          local statistics = force.get_item_production_statistics(surface)
          handled = progress_tracker_store.sync_item_production_statistics(
            state,
            force_name,
            surface_name,
            statistics
          ) or handled
        end
      end
    end
  end

  return handled
end

return M
