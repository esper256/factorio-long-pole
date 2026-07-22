-- A physical blueprint book is parsed into a cheap plan snapshot.
defines = {
  inventory = {
    item_main = 1
  }
}

local function blueprint(label, description, entities)
  return {
    valid_for_read = true,
    is_blueprint = true,
    label = label,
    blueprint_description = description,
    get_blueprint_entities = function()
      return entities
    end
  }
end

local function split_book(label, description, pages)
  return {
    valid_for_read = true,
    is_blueprint_book = true,
    label = label,
    blueprint_description = description,
    get_inventory = function(index)
      assert(index == defines.inventory.item_main)
      return pages
    end
  }
end

local book = {
  is_blueprint_book = true,
  label = "Any% Nauvis [LP]",
  get_inventory = function(index)
    assert(index == defines.inventory.item_main)
    return {
      blueprint("Burner phase", [[
notes for the human stay outside the owned data block
====== long-pole data-begin ======
# A comment is ignored.
research automation
item iron-plate 8
item iron-plate 2
item coal 500
====== long-pole data-end ======
]], {
        {name = "burner-mining-drill"},
        {name = "stone-furnace"},
        {name = "stone-furnace"}
      }),
      split_book("Research", [[
====== long-pole data-begin ======
research automation
====== long-pole data-end ======
]], {
        blueprint("Lab pair", "", {
          {name = "lab"},
          {name = "lab"}
        }),
        blueprint("Inserter", "", {
          {name = "burner-inserter"}
        })
      })
    }
  end
}

local loader = require("storage.blueprint_book_plan_loader")
local plan, load_error = loader.load_book(book)
assert(plan, load_error)
assert(plan.label == "Any% Nauvis [LP]")
assert(plan:split_count() == 2)

local burner_phase = plan:split_at(1)
assert(burner_phase.label == "Burner phase")
assert(burner_phase:entity_count("stone-furnace") == 2)
assert(burner_phase:entity_count("lab") == 0)
assert(burner_phase:extra_item_count("iron-plate") == 10)
assert(burner_phase:extra_item_count("coal") == 500)
assert(burner_phase:requires_research("automation"))
assert(not burner_phase:requires_research("logistics"))

local research = plan:split_at(2)
assert(research:entity_count("lab") == 2)
assert(research:entity_count("burner-inserter") == 1)
assert(research:extra_item_count("iron-plate") == 0)
assert(research:requires_research("automation"))

local malformed = {
  is_blueprint_book = true,
  label = "Broken [LP]",
  get_inventory = function()
    return {
      blueprint("Bad split", "====== long-pole data-begin ======\nitem iron-plate zero", {})
    }
  end
}

local console_messages = {}
local player = {
  print = function(message)
    console_messages[#console_messages + 1] = message
  end
}

local malformed_plan, malformed_error = loader.load_book_for_player(player, malformed)
assert(malformed_plan == nil)
assert(malformed_error:find("positive whole%-number count"))
assert(console_messages[1]:find("positive whole%-number count"))

local unmarked_book = {
  is_blueprint_book = true,
  label = "Megabase rail grid",
  get_inventory = function()
    error("an unmarked book must not be inspected")
  end
}

local unmarked_plan, unmarked_error = loader.load_book_for_player(player, unmarked_book)
assert(unmarked_plan == nil)
assert(unmarked_error == "blueprint book label must end with [LP]")
assert(console_messages[2] == "[Long Pole] blueprint book label must end with [LP]")

local nested_book = {
  is_blueprint_book = true,
  label = "Nested [LP]",
  get_inventory = function()
    return {
      split_book("Not allowed", "", {
        split_book("Nested again", "", {})
      })
    }
  end
}

local nested_plan, nested_error = loader.load_book(nested_book)
assert(nested_plan == nil)
assert(nested_error == "book page 1 page 1 must be a blueprint, not a nested book or planner")
