local speedrun_plan = require("speedrun_plan.plan")
local speedrun_attempt = require("speedrun_plan.attempt")
local current_split_quickbar = require("runtime.current_split_quickbar")

local plan = speedrun_plan.new("Practice [LP]", {
  {
    label = "First",
    source_page_index = 4,
    placement_item_counts = {},
    extra_item_counts = {},
    research_technologies = {}
  }
})
local attempt = speedrun_attempt.new(plan, 2)
local placed_slot
local player = {
  blueprints = {
    [2] = {
      type = "blueprint-book",
      contents = {
        [4] = { type = "blueprint", label = "First" }
      }
    }
  },
  quick_bar_width = 10,
  set_quick_bar_slot = function(page_index, slot_index, slot)
    placed_slot = { page_index = page_index, slot_index = slot_index, slot = slot }
  end,
  print = function()
    error("the source record should be present")
  end
}

assert(current_split_quickbar.update(player, attempt))
assert(placed_slot.page_index == 1)
assert(placed_slot.slot_index == 10)
assert(placed_slot.slot.type == "record")
assert(placed_slot.slot.record == player.blueprints[2].contents[4])
