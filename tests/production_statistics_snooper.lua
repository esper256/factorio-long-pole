-- Exercises a full production-statistics reconciliation without Factorio.
storage = {}

local statistics = {
  input_quality_counts = {
    normal = {
      ["iron-plate"] = 10,
      ["copper-plate"] = 4
    },
    uncommon = {
      ["iron-plate"] = 2
    }
  },
  output_quality_counts = {
    normal = {
      ["iron-plate"] = 7,
      ["copper-plate"] = 1
    }
  },
  current_input_quality_samples = {
    normal = {
      ["iron-plate"] = 3
    }
  },
  current_output_quality_samples = {
    normal = {
      ["iron-plate"] = 2
    }
  }
}

game = {
  forces = {
    player = {
      get_item_production_statistics = function(surface)
        assert(surface.name == "nauvis")
        return statistics
      end
    }
  },
  surfaces = {
    {
      name = "nauvis"
    }
  }
}

local snooper = require("snoopers.production_statistics")
snooper.on_second_tick({})

local products = storage.long_pole.debug_game_state.surfaces.nauvis.products
assert(products["iron-plate"].produced == 15)
assert(products["iron-plate"].consumed == 9)
assert(products["copper-plate"].produced == 4)
assert(products["copper-plate"].consumed == 1)

statistics.input_quality_counts = {
  normal = {
    ["iron-plate"] = 1
  }
}
statistics.output_quality_counts = {}
statistics.current_input_quality_samples = {}
statistics.current_output_quality_samples = {}
snooper.on_second_tick({})

assert(products["iron-plate"].produced == 1)
assert(products["iron-plate"].consumed == 0)
assert(products["copper-plate"].produced == 0)
assert(products["copper-plate"].consumed == 0)
