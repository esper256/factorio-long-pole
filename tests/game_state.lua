local game_state = require("game_state.game_state")

local state = game_state.new()
assert(state.lab_working_count == 0)

local nauvis = game_state.surface(state, "nauvis")
nauvis:record_products_unplaced({ ["stone-furnace"] = 1 })
assert(nauvis.state.surfaces.nauvis.products["stone-furnace"].placed == 0)

nauvis:record_products_harvested({ coal = 10 })
nauvis:record_products_placed({ coal = 3 })
assert(game_state.loose_stock(state.surfaces.nauvis.products.coal) == 7)
assert(game_state.total_loose_stock(state, "coal") == 7)

nauvis:record_products_destroyed({ coal = 20 })
assert(game_state.loose_stock(state.surfaces.nauvis.products.coal) == 0)
assert(game_state.total_loose_stock(state, "coal") == 0)

game_state.set_lab_throughput(state, 3)
assert(state.lab_working_count == 3)
