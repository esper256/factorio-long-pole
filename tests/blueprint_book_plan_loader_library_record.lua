-- Blueprint-library book records use a sparse contents map; page order is the
-- numeric record index, not Lua table iteration order.
prototypes = {
  entity = {
    ["burner-mining-drill"] = { items_to_place_this = { { name = "burner-mining-drill", count = 1 } } },
    ["lab"] = { items_to_place_this = { { name = "lab", count = 1 } } },
    ["burner-inserter"] = { items_to_place_this = { { name = "burner-inserter", count = 1 } } }
  },
  technology = {
    automation = {}
  }
}

local record_book = {
  type = "blueprint-book",
  label = "Library plan [LP]",
  contents = {
    [7] = {
      type = "blueprint-book",
      label = "Second split",
      blueprint_description = [[
====== long-pole data-begin ======
research automation
====== long-pole data-end ======
]],
      contents = {
        [1] = {
          type = "blueprint",
          get_blueprint_entities = function()
            return {
              {name = "lab"},
              {name = "lab"}
            }
          end
        },
        [2] = {
          type = "blueprint",
          get_blueprint_entities = function()
            return {
              {name = "burner-inserter"}
            }
          end
        },
        [3] = {
          type = "deconstruction-planner"
        },
        [4] = {
          type = "upgrade-planner"
        }
      }
    },
    [2] = {
      type = "blueprint",
      label = "First split",
      blueprint_description = "",
      get_blueprint_entities = function()
        return {
          {name = "burner-mining-drill"}
        }
      end
    },
    [11] = {
      type = "deconstruction-planner",
      label = "Harvest coal rocks",
      planner_description = [[
====== long-pole data-begin ======
item coal 50
====== long-pole data-end ======
]]
    },
    [15] = {
      type = "upgrade-planner",
      label = "Upgrade furnaces",
      planner_description = ""
    }
  }
}

local loader = require("storage.blueprint_book_plan_loader")
local plan, load_error = loader.load_book(record_book)
assert(plan, load_error)
assert(plan:split_at(1).label == "First split")
assert(plan:split_at(2).label == "Second split")
assert(plan:split_at(1):source_page() == 2)
assert(plan:split_at(2):source_page() == 7)
assert(plan:split_at(3).label == "Harvest coal rocks")
assert(plan:split_at(3):source_page() == 11)
assert(plan:split_at(3):placement_item_count("burner-mining-drill") == 0)
assert(plan:split_at(3):extra_item_count("coal") == 50)
assert(plan:split_at(4).label == "Upgrade furnaces")
assert(plan:split_at(4):source_page() == 15)
assert(plan:split_at(4):placement_item_count("stone-furnace") == 0)
assert(plan:split_at(1):placement_item_count("burner-mining-drill") == 1)
assert(plan:split_at(2):placement_item_count("lab") == 2)
assert(plan:split_at(2):placement_item_count("burner-inserter") == 1)
assert(plan:split_at(2):requires_research("automation"))

local printed_messages = {}
local player = {
  blueprints = {
    {
      type = "blueprint-book",
      label = "Megabase rail grid",
      contents = function()
        error("unmarked books must not be opened")
      end
    },
    record_book
  },
  print = function(message)
    printed_messages[#printed_messages + 1] = message
  end
}

local next_plan, library_book_index = loader.load_next_library_book_for_player(player, 0)
assert(next_plan.label == "Library plan [LP]")
assert(library_book_index == 2)

local first_plan, first_library_book_index = loader.load_first_library_book_for_player(player)
assert(first_plan.label == "Library plan [LP]")
assert(first_library_book_index == 2)

local no_plan = loader.load_next_library_book_for_player(player, 2)
assert(no_plan == nil)
assert(printed_messages[1] == "[Long Pole] No later [LP] blueprint book was found in your library.")
