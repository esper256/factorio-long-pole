local unfinished_items = require("progress_analysis.unfinished_items")

local entries = unfinished_items.sort({
  { item_name = "iron-gear-wheel", count = 12 },
  { item_name = "copper-plate", count = 20 },
  { item_name = "coal", count = 12 }
})

assert(entries[1].item_name == "copper-plate")
assert(entries[2].item_name == "coal")
assert(entries[3].item_name == "iron-gear-wheel")

local by_eta = unfinished_items.sort({
  { item_name = "belts", count = 1000, eta_ticks = 60 },
  { item_name = "gears", count = 12, eta_ticks = 600 }
})
assert(by_eta[1].item_name == "gears")
assert(by_eta[2].item_name == "belts")
