-- Exercises space platform construction without launching Factorio.
storage = {}

local snooper = require("snoopers.space_platform_built_entity")
snooper.on_event({
  entity = {
    name = "space-platform-foundation",
    surface = {
      name = "platform-1"
    }
  },
  stack = {
    name = "space-platform-foundation",
    count = 1
  }
})

local surface = storage.long_pole.ledger.surfaces["platform-1"]
assert(surface.placed_entities["space-platform-foundation"].placed == 1)
assert(surface.products["space-platform-foundation"].placed == 1)

snooper.on_event({
  entity = {
    type = "entity-ghost",
    surface = {
      name = "platform-1"
    }
  },
  stack = {
    name = "space-platform-foundation",
    count = 1
  }
})

assert(surface.placed_entities["space-platform-foundation"].placed == 1)
