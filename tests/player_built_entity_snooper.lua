-- Exercises player entity placement with an event-shaped consumed-items list.
storage = {}

local snooper = require("snoopers.player_built_entity")
snooper.on_event({
  entity = {
    name = "burner-mining-drill",
    surface = {
      name = "nauvis"
    }
  },
  consumed_items = {
    get_contents = function()
      return {
        {
          name = "burner-mining-drill",
          count = 1
        },
        {
          name = "iron-plate",
          count = 5
        }
      }
    end
  }
})

local surface = storage.long_pole.debug_game_state.surfaces.nauvis
assert(surface.placed_entities["burner-mining-drill"].placed == 1)
assert(surface.products["burner-mining-drill"].placed == 1)
assert(surface.products["iron-plate"].placed == 5)

snooper.on_event({
  entity = {
    type = "entity-ghost",
    surface = {
      name = "nauvis"
    }
  },
  consumed_items = {
    get_contents = function()
      error("ghosts should not inspect consumed items")
    end
  }
})

assert(surface.placed_entities["burner-mining-drill"].placed == 1)
