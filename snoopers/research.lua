-- Mirrors live research and lab throughput into the ledger.
--
-- Force research progress is a perfect API: copy only the current technology
-- plus on_research_finished, never walk every prototype. Lab working count is
-- polled so progress analysis can show lab-limited remaining work.
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")

local M = {}

M.event_names = {
  "on_research_finished"
}

local function record_current_research(force)
  local ledger = long_pole_runtime_state.ledger()
  local current_research = force.current_research
  if current_research then
    game_state.set_research(ledger, current_research.name, false, force.research_progress)
  end
end

local function count_working_labs(force)
  local working = 0
  if not (game and game.surfaces and defines and defines.entity_status) then
    return working
  end
  for _, surface in pairs(game.surfaces) do
    if surface.find_entities_filtered then
      for _, lab in pairs(surface.find_entities_filtered({ type = "lab", force = force })) do
        if lab.status == defines.entity_status.working then
          working = working + 1
        end
      end
    end
  end
  return working
end

function M.on_init()
  record_current_research(game.forces.player)
  game_state.set_lab_throughput(long_pole_runtime_state.ledger(), count_working_labs(game.forces.player))
end

function M.on_second_tick(_event)
  local force = game.forces.player
  record_current_research(force)
  game_state.set_lab_throughput(long_pole_runtime_state.ledger(), count_working_labs(force))
end

function M.on_event(event)
  local research = event.research
  if not research then
    return
  end
  game_state.set_research(long_pole_runtime_state.ledger(), research.name, true, 1)
end

return M
