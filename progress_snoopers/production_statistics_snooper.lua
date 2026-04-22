local progress_tracker_store = require("progress_tracker_store")

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

function M.poll(state, runtime)
  local runtime_root = runtime or rawget(_G, "game")
  if not (runtime_root and runtime_root.forces and runtime_root.surfaces) then
    return false
  end

  local handled = false

  for _, force in pairs(runtime_root.forces) do
    if force and force.name and force.get_item_production_statistics then
      for _, surface in pairs(runtime_root.surfaces) do
        local surface_name = surface and surface.name or nil
        if surface_name then
          local statistics = force.get_item_production_statistics(surface)
          handled = progress_tracker_store.sync_item_production_statistics(
            state,
            force.name,
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
