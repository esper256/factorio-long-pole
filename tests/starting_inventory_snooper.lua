-- Exercises first-game initialization without launching Factorio.
storage = {}
game = {
  tick = 0
}

local snooper = require("snoopers.starting_inventory")
snooper.on_init()

local products = storage.long_pole.debug_game_state.surfaces.nauvis.products
assert(products.wood.produced == 1)
assert(products["stone-furnace"].produced == 1)
assert(products["burner-mining-drill"].produced == 1)
assert(products["iron-plate"].produced == 8)
assert(products["firearm-magazine"].produced == 10)

storage = {}
game.tick = 1
snooper.on_init()
assert(storage.long_pole == nil)
