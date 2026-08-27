-- Entity removal is tracked separately from returned-item accounting.
storage = {}

local snooper = require("snoopers.player_mined_entity")

local game_state = require("game_state.game_state")
local initial_state = require("runtime_state.long_pole_runtime_state").get().debug_game_state
local nauvis = game_state.surface(initial_state, "nauvis")
nauvis:record_placed_entities({
  ["burner-mining-drill"] = 1
})
nauvis:record_products_placed({
  ["burner-mining-drill"] = 1
})

snooper.on_event({
  entity = {
    name = "burner-mining-drill",
    type = "mining-drill",
    surface = {
      name = "nauvis"
    },
    prototype = {
      items_to_place_this = {
        {
          name = "burner-mining-drill",
          count = 1
        }
      }
    }
  },
  buffer = {
    get_contents = function()
      return {
        {
          name = "burner-mining-drill",
          count = 1
        }
      }
    end
  }
})

assert(initial_state.surfaces.nauvis.placed_entities["burner-mining-drill"].placed == 0)
assert(initial_state.surfaces.nauvis.products["burner-mining-drill"].placed == 0)

snooper.on_event({
  entity = {
    name = "tree-01",
    type = "tree",
    surface = {
      name = "nauvis"
    },
    prototype = {}
  },
  buffer = {
    get_contents = function()
      return {
        {
          name = "wood",
          count = 4
        }
      }
    end
  }
})

local surface = storage.long_pole.debug_game_state.surfaces.nauvis
assert(surface.products.wood.harvested == 4)

snooper.on_event({
  entity = {
    name = "rock-big",
    type = "simple-entity",
    surface = {
      name = "nauvis"
    },
    prototype = {}
  },
  buffer = {
    get_contents = function()
      return {
        {
          name = "coal",
          count = 2
        },
        {
          name = "stone",
          count = 1
        }
      }
    end
  }
})

assert(surface.products.coal.harvested == 2)
assert(surface.products.stone.harvested == 1)

snooper.on_event({
  entity = {
    name = "iron-ore",
    type = "resource",
    surface = {
      name = "nauvis"
    },
    prototype = {}
  },
  buffer = {
    get_contents = function()
      error("ore patches are accounted for by production statistics")
    end
  }
})

assert(surface.products["iron-ore"] == nil)
