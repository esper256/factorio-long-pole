-- Entity removal is tracked separately from returned-item accounting.
storage = {}

local snooper = require("snoopers.player_mined_entity")

local game_state = require("game_state.game_state")
local initial_state = require("runtime_state.long_pole_runtime_state").ledger()
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

local surface = storage.long_pole.ledger.surfaces.nauvis
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

-- Unplace without a recorded placement must not assert.
snooper.on_event({
  entity = {
    name = "stone-furnace",
    type = "furnace",
    surface = { name = "nauvis" },
    prototype = {
      items_to_place_this = {
        { name = "stone-furnace", count = 1 }
      }
    }
  },
  buffer = {
    get_contents = function()
      return { { name = "stone-furnace", count = 1 } }
    end
  }
})
assert(surface.products["stone-furnace"].placed == 0)

-- Crash-site wrecks have no placement item; buffer loot is harvested.
snooper.on_event({
  entity = {
    name = "crash-site-chest",
    type = "container",
    surface = { name = "nauvis" },
    prototype = {}
  },
  buffer = {
    get_contents = function()
      return { { name = "iron-plate", count = 8 } }
    end
  }
})
assert(surface.products["iron-plate"].harvested == 8)

-- Death of a placed building records destroyed instead of unplaced.
nauvis:record_placed_entities({ lab = 1 })
nauvis:record_products_placed({ lab = 1 })
snooper.on_event({
  died = true,
  entity = {
    name = "lab",
    type = "lab",
    surface = { name = "nauvis" },
    prototype = {
      items_to_place_this = {
        { name = "lab", count = 1 }
      }
    }
  }
})
assert(surface.placed_entities.lab.placed == 1)
assert(surface.placed_entities.lab.destroyed == 1)
assert(surface.products.lab.destroyed == 1)

-- Robot mining of trees uses the same harvest path as player mining.
snooper.on_event({
  entity = {
    name = "tree-02",
    type = "tree",
    surface = { name = "nauvis" },
    prototype = {}
  },
  buffer = {
    get_contents = function()
      return { { name = "wood", count = 2 } }
    end
  }
})
assert(surface.products.wood.harvested == 6)

-- script_raised_destroy of a placed building records destroyed, not unplaced.
defines = {
  events = {
    on_entity_died = 10,
    script_raised_destroy = 11
  }
}
nauvis:record_placed_entities({ ["stone-furnace"] = 1 })
nauvis:record_products_placed({ ["stone-furnace"] = 1 })
snooper.on_event({
  name = 11,
  entity = {
    name = "stone-furnace",
    type = "furnace",
    surface = { name = "nauvis" },
    prototype = {
      items_to_place_this = {
        { name = "stone-furnace", count = 1 }
      }
    }
  }
})
assert(surface.placed_entities["stone-furnace"].destroyed == 1)
assert(surface.products["stone-furnace"].destroyed == 1)

