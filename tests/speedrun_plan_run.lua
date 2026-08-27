-- Walks the exported 100% DS Speedrun [LP] plan through mocked Factorio
-- events: library load, placement, harvest vs patch ore, stock-once copper,
-- research, auto-advance, and ungated hotkeys.
local session = require("test_support.factorio_session")
local loader = require("storage.blueprint_book_plan_loader")

session.boot({ auto_advance = true })
session.init()
session.tick()

local book = session.player().blueprints[1]
local plan, load_error = loader.load_book(book)
assert(plan, load_error)
assert(plan.label == "100% DS Speedrun [LP]")
assert(plan:split_count() == 10)
assert(plan:split_at(1).label == "First burner")
assert(plan:split_at(1):placement_item_count("stone-furnace") == 1)
assert(plan:split_at(1):placement_item_count("burner-mining-drill") == 1)
assert(plan:split_at(1):extra_item_count("coal") == 20)
assert(plan:split_at(2).label == "Second burner")
assert(plan:split_at(3).label == "Mine coal rocks")
assert(plan:split_at(3):placement_item_count("stone-furnace") == 0)
assert(plan:split_at(3):extra_item_count("coal") == 300)
assert(plan:split_at(4).label == "Copper Hand Smelter")
assert(plan:split_at(4):placement_item_count("stone-furnace") == 2)
assert(plan:split_at(4):extra_item_count("copper-ore") == 12)
assert(plan:split_at(4):extra_item_count("lab") == 1)
assert(plan:split_at(4):extra_item_count("automation-science-pack") == 10)
assert(plan:split_at(5):requires_research("automation"))
assert(plan:split_at(6).label == "First assembler")
assert(plan:split_at(8).label == "Half-lane mine")
assert(plan:split_at(8):placement_item_count("electric-mining-drill") == 15)
assert(plan:split_at(9).label == "Lazy intermediate mall")
assert(plan:split_at(9):placement_item_count("inserter") == 107)
assert(plan:split_at(9):placement_item_count("transport-belt") == 176)
assert(plan:split_at(10).label == "Half-lane mine")

local function remaining(progress, item_name)
  local total = 0
  if not progress then
    return 0
  end
  for _, item in ipairs(progress.unfinished_items or {}) do
    if item.item_name == item_name then
      total = total + item.count
    end
  end
  return total
end

local function copper_remaining(progress)
  return remaining(progress, "copper-ore")
    + remaining(progress, "copper-plate")
    + remaining(progress, "copper-cable")
end

local hud = session.hud()
assert(hud.type == "flow")
assert(hud.style.width == 192)
assert(hud.style.padding == 0)
assert(hud.current_split.caption:find("First burner", 1, true))
assert(hud.long_pole_advance_split.caption == "Second burner")
assert(hud.speedrun_header.active_speedrun_name.caption == "100% DS Speedrun")

local starter = session.product("stone-furnace")
assert(starter.harvested == 1)
assert(session.product("burner-mining-drill").harvested == 1)
assert(session.product("iron-plate").harvested == 8)

local first = session.analyze()
assert(first.current_split_label == "First burner")
assert(first.next_split_label == "Second burner")
assert(first.construction_progress.total == 2)
assert(first.construction_progress.done == 0)
assert(first.construction_progress.pending == 2)
assert(remaining(first.next_split_production_progress, "coal") == 0)

session.place_current_print()
session.tick()
assert(session.analyze().current_split_label == "Second burner")
assert(session.hud().previous_split.caption:find("First burner", 1, true))

local second = session.analyze()
assert(second.next_split_label == "Mine coal rocks")
assert(remaining(second.next_split_production_progress, "coal") == 300)

session.mine_rock({ coal = 8, stone = 2 })
session.tick()
assert(session.product("coal").harvested == 8)
assert((session.product("coal").produced or 0) == 0)
assert(session.product("stone").harvested == 2)
assert(remaining(session.analyze().next_split_production_progress, "coal") == 292)

session.place_current_print()
session.tick()
assert(session.analyze().current_split_label == "Mine coal rocks")
assert(session.analyze().construction_progress.total == 0)

local copper_split = session.analyze()
assert(copper_split.next_split_label == "Copper Hand Smelter")
local empty_copper = copper_remaining(copper_split.next_split_production_progress)
assert(empty_copper >= 30)

session.mine_ore("copper-ore", 15)
session.tick()
local copper_ore = session.product("copper-ore")
assert(copper_ore.produced == 15)
assert((copper_ore.harvested or 0) == 0)

local after_fifteen = session.analyze().next_split_production_progress
assert(copper_remaining(after_fifteen) > 0)
assert(copper_remaining(after_fifteen) >= 15)
assert(after_fifteen.total - after_fifteen.pending > 12)

session.press("long-pole-rewind-split")
assert(session.analyze().current_split_label == "Second burner")
session.press("long-pole-advance-split")
assert(session.analyze().current_split_label == "Mine coal rocks")

session.click("long_pole_advance_split")
assert(session.analyze().current_split_label == "Copper Hand Smelter")
assert(session.analyze().construction_progress.total == 2)

session.place_current_print()
session.tick()
assert(session.analyze().current_split_label == "Power and First Lab")
assert(session.analyze().construction_progress.total == 5)
assert(session.analyze().research_progress.total == 10)
assert(session.analyze().research_progress.done == 0)

session.begin_research("automation", 0.4)
session.consume({ ["automation-science-pack"] = 4 })
session.tick()
local mid_research = session.analyze().research_progress
assert(mid_research.done > 0)
assert(mid_research.done < 10)
assert(remaining(mid_research, "automation-science-pack") > 0)
assert(mid_research.working_labs == 0)

session.place_current_print()
session.finish_research("automation")
session.tick()
assert(session.analyze().current_split_label == "First assembler")
assert(session.ledger().lab_working_count == 1)
assert(session.hud().research_progress.visible == false)

session.robot_build("assembling-machine-1")
session.tick()
assert(session.analyze().current_split_label == "Lazy Handfeed")

session.place_current_print()
session.tick()
assert(session.analyze().current_split_label == "Half-lane mine")
session.place_current_print()
session.tick()
assert(session.analyze().current_split_label == "Lazy intermediate mall")
session.place_current_print()
session.tick()
assert(session.analyze().current_split_label == "Half-lane mine")
session.place_current_print()
session.tick()
assert(session.analyze().current_split_label == "Half-lane mine")
assert(session.analyze().next_split_label == nil)

session.press("long-pole-advance-split")
local done = session.analyze()
assert(done.current_split_label == "Plan complete")
assert(done.next_split_label == nil)
assert(session.hud().long_pole_advance_split.visible == false)
assert(session.hud().current_split.caption:find("Plan complete", 1, true))

session.press("long-pole-toggle-debug-window")
assert(session.player().gui.left.long_pole_debug_state_panel ~= nil)
session.tick()
session.press("long-pole-toggle-debug-window")
assert(session.player().gui.left.long_pole_debug_state_panel == nil)
