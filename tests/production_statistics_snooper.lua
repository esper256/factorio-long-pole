-- Exercises a full production-statistics reconciliation without Factorio.
storage = {}
defines = {
  flow_precision_index = {
    one_minute = 1
  }
}

local statistics = {
  input_counts = {
    ["iron-plate"] = 12,
    ["copper-plate"] = 4
  },
  output_counts = {
    ["iron-plate"] = 9,
    ["copper-plate"] = 1
  },
  get_flow_count = function(query)
    if query.category == "input" then
      return ({ ["iron-plate"] = 60, ["copper-plate"] = 12 })[query.name] or 0
    end
    return ({ ["iron-plate"] = 30, ["copper-plate"] = 6 })[query.name] or 0
  end
}

local fluid_statistics = {
  input_counts = {
    water = 100
  },
  output_counts = {
    water = 40
  },
  get_flow_count = function(query)
    if query.name ~= "water" then
      return 0
    end
    if query.category == "input" then
      return 240
    end
    return 90
  end
}

game = {
  forces = {
    player = {
      get_item_production_statistics = function(surface)
        assert(surface.name == "nauvis" or surface.name == "platform-1")
        return statistics
      end,
      get_fluid_production_statistics = function(surface)
        assert(surface.name == "nauvis")
        return fluid_statistics
      end
    }
  },
  surfaces = {
    {
      name = "nauvis"
    }
  }
}

local game_state = require("game_state.game_state")
local snooper = require("snoopers.production_statistics")
local ledger = require("runtime_state.long_pole_runtime_state").ledger()
game_state.surface(ledger, "nauvis"):record_products_harvested({ wood = 4 })
snooper.on_second_tick({})

local products = storage.long_pole.ledger.surfaces.nauvis.products
assert(products["iron-plate"].produced == 12)
assert(products["iron-plate"].consumed == 9)
assert(products["iron-plate"].produced_per_minute == 60)
assert(products["iron-plate"].consumed_per_minute == 30)
assert(products["copper-plate"].produced == 4)
assert(products["copper-plate"].consumed == 1)
assert(products.water.produced == 100)
assert(products.water.consumed == 40)
assert(products.water.produced_per_minute == 240)
assert(products.wood.harvested == 4)
assert(products.wood.produced == 0)

statistics.input_counts = { ["iron-plate"] = 1 }
statistics.output_counts = {}
fluid_statistics.input_counts = {}
fluid_statistics.output_counts = {}
snooper.on_second_tick({})

assert(products["iron-plate"].produced == 1)
assert(products["iron-plate"].consumed == 0)
assert(products["copper-plate"].produced == 0)
assert(products.water.produced == 0)
assert(products.wood.harvested == 4)

-- The same statistics userdata on a second surface must not double loose stock.
statistics.input_counts = { ["copper-ore"] = 15 }
statistics.output_counts = {}
game.surfaces = {
  { name = "nauvis" },
  { name = "platform-1" }
}
snooper.on_second_tick({})
assert(storage.long_pole.ledger.surfaces.nauvis.products["copper-ore"].produced == 15)
local platform_ore = storage.long_pole.ledger.surfaces["platform-1"].products["copper-ore"]
assert(platform_ore == nil or platform_ore.produced == 0)
assert(game_state.total_loose_stock(ledger, "copper-ore") == 15)
