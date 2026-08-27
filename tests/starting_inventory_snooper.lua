-- Starter items are a separate non-statistical harvested source.
storage = {}
game = {
  tick = 0
}

local snooper = require("snoopers.starting_inventory")
snooper.on_init()

local products = storage.long_pole.ledger.surfaces.nauvis.products
assert(products.wood.harvested == 1)
assert(products["stone-furnace"].harvested == 1)
assert(products["burner-mining-drill"].harvested == 1)
assert(products["iron-plate"].harvested == 8)
assert(products["firearm-magazine"].harvested == 10)
