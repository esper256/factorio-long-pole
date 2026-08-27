-- Research progress is force-level state. The active technology uses the
-- force's live progress; inactive technologies retain their saved progress.
storage = {}
game = {
  forces = {
    player = {
      current_research = {
        name = "automation"
      },
      research_progress = 0.4,
      technologies = {
        automation = {
          researched = false,
          saved_progress = 0.1
        },
        logistics = {
          researched = false,
          saved_progress = 0.25
        },
        ["steel-processing"] = {
          researched = true,
          saved_progress = 0
        }
      }
    }
  }
}

local snooper = require("snoopers.research")
snooper.on_init()

local research = storage.long_pole.debug_game_state.research
assert(research.automation.researched == false)
assert(research.automation.progress == 0.4)
assert(research.logistics.researched == false)
assert(research.logistics.progress == 0.25)
assert(research["steel-processing"].researched == true)
assert(research["steel-processing"].progress == 1)

game.forces.player.current_research = nil
game.forces.player.technologies.automation.saved_progress = 0.6
snooper.on_second_tick({})
assert(research.automation.progress == 0.6)
