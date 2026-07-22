-- Save-local singleton for `storage.long_pole`. This belongs to runtime_state,
-- not storage: `storage/` is reserved for cross-save plan transport.
local mock_game_state = require("test_support.mock_game_state")

local M = {}

function M.get()
  if storage.long_pole == nil then
    storage.long_pole = {
      debug_game_state = mock_game_state.sample()
    }
  elseif storage.long_pole.debug_game_state == nil then
    storage.long_pole.debug_game_state = mock_game_state.sample()
  end

  return storage.long_pole
end

return M
