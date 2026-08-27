-- Save-local singleton for `storage.long_pole`. This belongs to runtime_state,
-- not storage: `storage/` is reserved for cross-save plan transport.
local game_state = require("game_state.game_state")

local M = {}

local function migrate_ledger(runtime_state)
  if runtime_state.ledger == nil then
    runtime_state.ledger = runtime_state.debug_game_state or game_state.new()
    runtime_state.debug_game_state = nil
  end
  return runtime_state.ledger
end

function M.get()
  if storage.long_pole == nil then
    storage.long_pole = {
      ledger = game_state.new()
    }
  end
  migrate_ledger(storage.long_pole)
  return storage.long_pole
end

function M.ledger()
  return M.get().ledger
end

return M
