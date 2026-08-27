-- Exercises construction-robot entity placement without launching Factorio.
storage = {}

local snooper = require("snoopers.robot_built_entity")
snooper.on_event({
  entity = {
    name = "stone-furnace",
    surface = {
      name = "nauvis"
    }
  },
  stack = {
    name = "stone-furnace",
    count = 1
  }
})

local surface = storage.long_pole.debug_game_state.surfaces.nauvis
assert(surface.placed_entities["stone-furnace"].placed == 1)
assert(surface.products["stone-furnace"].placed == 1)
