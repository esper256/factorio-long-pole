-- Save-local collection of each player's current speedrun attempt.
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")
local speedrun_attempt = require("speedrun_plan.attempt")

local M = {}

local function attempts_by_player()
  local runtime_state = long_pole_runtime_state.get()
  if runtime_state.speedrun_attempts == nil then
    runtime_state.speedrun_attempts = {}
  end
  return runtime_state.speedrun_attempts
end

function M.get(player_index)
  return attempts_by_player()[player_index]
end

function M.start(player_index, plan, library_book_index, state)
  local attempt = speedrun_attempt.new(plan, library_book_index, state)
  attempts_by_player()[player_index] = attempt
  return attempt
end

return M
