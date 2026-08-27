-- Mirrors Factorio's authoritative force research state into the game ledger.
-- Research progress belongs to the force, so polling once per second captures
-- both the active technology and saved progress on interrupted technologies.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

local function record_force_research(force)
  local runtime_state = long_pole_runtime_state.get()
  local current_research = force.current_research

  for technology_name, technology in pairs(force.technologies) do
    local progress = technology.researched and 1 or technology.saved_progress
    if current_research and current_research.name == technology_name then
      progress = force.research_progress
    end
    game_state.set_research(
      runtime_state.debug_game_state,
      technology_name,
      technology.researched,
      progress
    )
  end
end

function M.on_init()
  record_force_research(game.forces.player)
end

function M.on_second_tick(_event)
  record_force_research(game.forces.player)
end

return M
