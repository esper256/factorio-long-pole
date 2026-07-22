-- Blueprint-library book records use a sparse contents map; page order is the
-- numeric record index, not Lua table iteration order.
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
    }
  }
}

local loader = require("storage.blueprint_book_plan_loader")
local plan, load_error = loader.load_book(record_book)
assert(plan, load_error)
assert(plan:split_at(1).label == "First split")
assert(plan:split_at(2).label == "Second split")
assert(plan:split_at(1):entity_count("burner-mining-drill") == 1)
assert(plan:split_at(2):entity_count("lab") == 2)
assert(plan:split_at(2):entity_count("burner-inserter") == 1)
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
