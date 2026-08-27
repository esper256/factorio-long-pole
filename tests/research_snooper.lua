-- The research snooper copies only the live current technology and lab count.
-- It does not walk every technology prototype.
storage = {}
game = {
  forces = {
    player = {
      current_research = {
        name = "automation"
      },
      research_progress = 0.4,
      technologies = {}
    }
  },
  surfaces = {}
}

local snooper = require("snoopers.research")
snooper.on_init()

local ledger = storage.long_pole.ledger
assert(ledger.research.automation.researched == false)
assert(ledger.research.automation.progress == 0.4)
assert(ledger.research.logistics == nil)
assert(ledger.lab_working_count == 0)

snooper.on_event({
  research = { name = "logistics" }
})
assert(ledger.research.logistics.researched == true)
assert(ledger.research.logistics.progress == 1)
