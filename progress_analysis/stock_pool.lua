-- A mutable remaining-stock pool. Loose stock must be spent once across
-- every requirement; crediting the same 15 ore against lab, science, and
-- extra copper-ore is what made a 30-plate step look done at 15.
local game_state = require("game_state.game_state")

local M = {}

function M.from_ledger(state, reserved)
  reserved = reserved or {}
  local taken = {}

  local api = {}

  function api.have(name)
    return math.max(
      0,
      game_state.total_loose_stock(state, name) - (reserved[name] or 0) - (taken[name] or 0)
    )
  end

  function api.take(name, amount)
    local need = math.max(0, amount or 0)
    local used = math.min(api.have(name), need)
    taken[name] = (taken[name] or 0) + used
    return used
  end

  return api
end

function M.from_map(stock)
  local remaining = {}
  for name, count in pairs(stock or {}) do
    remaining[name] = count
  end

  local api = {}

  function api.have(name)
    return math.max(0, remaining[name] or 0)
  end

  function api.take(name, amount)
    local need = math.max(0, amount or 0)
    local used = math.min(api.have(name), need)
    remaining[name] = api.have(name) - used
    return used
  end

  return api
end

return M
