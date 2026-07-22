-- Blueprint-library book records use a sparse contents map; page order is the
-- numeric record index, not Lua table iteration order.
local record_book = {
  type = "blueprint-book",
  label = "Library plan [LP]",
  contents = {
    [7] = {
      type = "blueprint",
      label = "Second split",
      blueprint_description = "",
      get_blueprint_entities = function()
        return {
          {name = "lab"}
        }
      end
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
assert(plan:split_at(2):entity_count("lab") == 1)
