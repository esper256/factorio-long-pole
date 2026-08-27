local plan_storage = require("plan_storage")
local tracker = require("split_tracker")

describe("plan_storage", function()
  local make_stack

  local function make_inventory(slot_count)
    local inventory = {}

    function inventory.insert(item)
      local current_size = #inventory
      if slot_count and current_size >= slot_count then
        return 0
      end

      local inserted = make_stack(slot_count)
      if not inserted.set_stack({name = item.name}) then
        return 0
      end

      inventory[current_size + 1] = inserted
      return 1
    end

    function inventory.find_empty_stack()
      for index = 1, #inventory do
        local candidate = inventory[index]
        if candidate and not candidate.valid_for_read then
          return candidate, index
        end
      end

      return nil, nil
    end

    return inventory
  end

  make_stack = function(slot_count)
    local stack = {
      valid_for_read = false,
      is_blueprint_book = false,
      is_blueprint = false,
      label = nil,
      active_index = nil,
      blueprint_entities = nil
    }

    local mt = {
      __index = stack,
      __newindex = function(table_self, key, value)
        if key == "blueprint_description" and rawget(table_self, "is_blueprint") and not rawget(table_self, "blueprint_entities") then
          error("description can not be set on an empty blueprint.")
        end
        rawset(table_self, key, value)
      end
    }
    setmetatable(stack, mt)

    function stack.clear()
      stack.valid_for_read = false
      stack.is_blueprint_book = false
      stack.is_blueprint = false
      stack.label = nil
      stack.active_index = nil
      stack.inventory = nil
      stack.blueprint_entities = nil
      rawset(stack, "blueprint_description", nil)
    end

    function stack.set_stack(spec)
      stack.clear()
      if spec.name == "blueprint-book" then
        stack.valid_for_read = true
        stack.is_blueprint_book = true
        stack.inventory = make_inventory(slot_count)
        return true
      end

      if spec.name == "blueprint" then
        stack.valid_for_read = true
        stack.is_blueprint = true
        return true
      end

      return false
    end

    function stack.get_inventory(_inventory_id)
      return stack.inventory
    end

    function stack.set_blueprint_entities(entities)
      stack.blueprint_entities = entities
    end

    function stack.get_blueprint_entity_count()
      return #(stack.blueprint_entities or {})
    end

    function stack.get_blueprint_entities()
      return stack.blueprint_entities or {}
    end

    return stack
  end

  local function ensure_slot(inventory, slot_index, slot_count)
    while #inventory < slot_index do
      inventory[#inventory + 1] = make_stack(slot_count)
    end

    return inventory[slot_index]
  end

  local function make_record(spec)
    local record = {
      valid = true,
      type = spec.type,
      label = spec.label,
      blueprint_description = spec.blueprint_description
    }

    if spec.export_string then
      function record.export_record()
        return spec.export_string
      end
    end

    if spec.type == "blueprint-book" then
      record.contents = spec.contents or {}
    end

    if spec.type == "blueprint" then
      record._entities = spec.entities or {}

      function record.get_blueprint_entity_count()
        return #record._entities
      end

      function record.get_blueprint_entities()
        return record._entities
      end

      function record.export_record()
        return spec.export_string
      end
    end

    return record
  end

  local function with_mocked_label_imports(label_by_export, callback)
    local previous_game = rawget(_G, "game")
    _G.game = {
      create_inventory = function(_size)
        local stack = {
          valid = true,
          label = nil
        }

        function stack.import_stack(data)
          stack.label = label_by_export[data]
          return stack.label and 0 or 1
        end

        return setmetatable({
          [1] = stack
        }, {
          __index = {
            destroy = function() end
          }
        })
      end
    }

    local ok, result = pcall(callback)
    _G.game = previous_game
    if not ok then
      error(result)
    end

    return result
  end

  it("decodes a nested book plan format from descriptions", function()
    local slot_count = 5
    local plan_book = make_stack(slot_count)
    assert.is_true(plan_book.set_stack({name = "blueprint-book"}))
    plan_book.label = "Any% Practice Plan"
    plan_book.blueprint_description = [[format=long-pole-plan;version=1
plan_id=plan-42
visibility=references-only
default_surface=nauvis
]]

    local split_book = ensure_slot(plan_book.get_inventory(1), 1, slot_count)
    assert.is_true(split_book.set_stack({name = "blueprint-book"}))
    split_book.label = "Starter Burners"
    split_book.blueprint_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
wood=8

--- Technologies to Research ---
automation

--- Notes ---
Feed gears before circuits.
]]

    local blueprint_link = ensure_slot(split_book.get_inventory(1), 1, slot_count)
    assert.is_true(blueprint_link.set_stack({name = "blueprint"}))
    blueprint_link.set_blueprint_entities({
      {
        entity_number = 1,
        name = "constant-combinator",
        position = {x = 0, y = 0}
      }
    })
    blueprint_link.label = "Starter burner pair"
    blueprint_link.blueprint_description = [[format=long-pole-blueprint-link;version=1
link_mode=reference
library_root=player-blueprints
inside_book=Any% Openers
inside_book=Burner Starts
blueprint_name=Starter burner pair
blueprint_slot=2
fingerprint=burner-mining-drill:2;stone-furnace:2
]]

    local decoded = assert(plan_storage.decode_plan_from_item_stack(plan_book))

    assert.same({
      plan_id = "plan-42",
      plan_name = "Any% Practice Plan",
      splits = {
        {
          name = "Starter Burners",
          surface = "nauvis",
          items = {
            {name = "wood", count = 8}
          },
          blueprints = {
            {
              format = "long-pole-blueprint-link",
              version = 1,
              link_mode = "reference",
              library_root = "player-blueprints",
              inside_books = {"Any% Openers", "Burner Starts"},
              blueprint_name = "Starter burner pair",
              blueprint_slot = 2,
              fingerprint = "burner-mining-drill:2;stone-furnace:2",
              name = "Starter burner pair",
              source_book_label = "Any% Openers",
              source_book_active_index = 2,
              entity_summary = {
                {name = "burner-mining-drill", count = 2},
                {name = "stone-furnace", count = 2}
              },
              entity_count = 4
            }
          },
          technologies = {
            {name = "automation"}
          },
          notes = "Feed gears before circuits."
        }
      }
    }, decoded)
  end)

  it("ignores blank slots while preserving the order of populated split books and blueprint links", function()
    local slot_count = 6
    local plan_book = make_stack(slot_count)
    assert.is_true(plan_book.set_stack({name = "blueprint-book"}))
    plan_book.label = "Gap Test Plan"
    plan_book.blueprint_description = [[format=long-pole-plan;version=1
plan_id=plan-gap
visibility=references-only
default_surface=nauvis
]]

    local first_split = ensure_slot(plan_book.get_inventory(1), 2, slot_count)
    assert.is_true(first_split.set_stack({name = "blueprint-book"}))
    first_split.label = "First Split"
    first_split.blueprint_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
wood=8

--- Technologies to Research ---
automation

--- Notes ---
First notes.
]]

    local first_blueprint = ensure_slot(first_split.get_inventory(1), 2, slot_count)
    assert.is_true(first_blueprint.set_stack({name = "blueprint"}))
    first_blueprint.set_blueprint_entities({
      {
        entity_number = 1,
        name = "constant-combinator",
        position = {x = 0, y = 0}
      }
    })
    first_blueprint.label = "First Blueprint"
    first_blueprint.blueprint_description = [[format=long-pole-blueprint-link;version=1
link_mode=reference
library_root=player-blueprints
inside_book=Openers
blueprint_name=First Blueprint
blueprint_slot=2
fingerprint=burner-mining-drill:2
]]

    local second_blueprint = ensure_slot(first_split.get_inventory(1), 5, slot_count)
    assert.is_true(second_blueprint.set_stack({name = "blueprint"}))
    second_blueprint.set_blueprint_entities({
      {
        entity_number = 1,
        name = "constant-combinator",
        position = {x = 0, y = 0}
      }
    })
    second_blueprint.label = "Second Blueprint"
    second_blueprint.blueprint_description = [[format=long-pole-blueprint-link;version=1
link_mode=reference
library_root=player-blueprints
inside_book=Openers
blueprint_name=Second Blueprint
blueprint_slot=5
fingerprint=stone-furnace:2
]]

    local second_split = ensure_slot(plan_book.get_inventory(1), 5, slot_count)
    assert.is_true(second_split.set_stack({name = "blueprint-book"}))
    second_split.label = "Second Split"
    second_split.blueprint_description = [[format=long-pole-split;version=1
surface=gleba

--- Extra Items ---
iron-gear-wheel=4

--- Technologies to Research ---
logistics

--- Notes ---
Second notes.
]]

    local decoded = assert(plan_storage.decode_plan_from_item_stack(plan_book))

    assert.are.equal(2, #decoded.splits)
    assert.are.equal("First Split", decoded.splits[1].name)
    assert.are.equal("Second Split", decoded.splits[2].name)
    assert.are.equal(2, #decoded.splits[1].blueprints)
    assert.are.equal("First Blueprint", decoded.splits[1].blueprints[1].name)
    assert.are.equal("Second Blueprint", decoded.splits[1].blueprints[2].name)
  end)

  it("exports the active plan as a nested book plan format", function()
    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Starter Burners")
    tracker.set_split_items(state, 1, {
      {name = "wood", count = 8}
    })
    tracker.set_split_technologies(state, 1, {
      {name = "automation"}
    })
    tracker.set_split_notes(state, 1, "Feed gears before circuits.")
    tracker.set_split_blueprints(state, 1, {
      {
        name = "Starter burner pair",
        source_book_label = "Any% Openers",
        source_book_active_index = 2,
        entity_summary = {
          {name = "burner-mining-drill", count = 2},
          {name = "stone-furnace", count = 2}
        },
        entity_count = 4
      }
    })

    local cursor_stack = make_stack(5)
    local player = {
      cursor_stack = cursor_stack
    }

    local ok, error_message = plan_storage.export_plan_to_cursor(player, state)

    assert.is_true(ok)
    assert.is_nil(error_message)
    assert.is_true(cursor_stack.valid_for_read)
    assert.is_true(cursor_stack.is_blueprint_book)
    assert.are.equal("Untitled Plan", cursor_stack.label)
    assert.are.equal([[format=long-pole-plan;version=1
plan_id=plan-1
visibility=references-only
default_surface=nauvis
]], cursor_stack.blueprint_description)

    local split_book = cursor_stack.get_inventory(1)[1]
    assert.is_true(split_book.valid_for_read)
    assert.is_true(split_book.is_blueprint_book)
    assert.are.equal("Starter Burners", split_book.label)
    assert.are.equal([[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
wood=8

--- Technologies to Research ---
automation

--- Notes ---
Feed gears before circuits.
]], split_book.blueprint_description)

    local blueprint_link = split_book.get_inventory(1)[1]
    assert.is_true(blueprint_link.valid_for_read)
    assert.is_true(blueprint_link.is_blueprint)
    assert.are.equal("Starter burner pair", blueprint_link.label)
    assert.are.equal([[format=long-pole-blueprint-link;version=1
link_mode=reference
library_root=player-blueprints
inside_book=Any% Openers
blueprint_name=Starter burner pair
blueprint_slot=2
fingerprint=burner-mining-drill:2;stone-furnace:2
]], blueprint_link.blueprint_description)
  end)

  it("fails cleanly when the top-level blueprint book cannot fit all splits", function()
    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Split 1")
    tracker.add_split(state, "Split 2")

    local player = {
      cursor_stack = make_stack(1)
    }

    local ok, error_message = plan_storage.export_plan_to_cursor(player, state)

    assert.is_false(ok)
    assert.are.equal("This plan has more splits than fit in one blueprint book.", error_message)
  end)

  it("fails cleanly when a split book cannot fit all linked blueprints", function()
    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Starter Burners")
    tracker.set_split_blueprints(state, 1, {
      {name = "Blueprint 1", entity_summary = {{name = "transport-belt", count = 1}}},
      {name = "Blueprint 2", entity_summary = {{name = "transport-belt", count = 2}}}
    })

    local player = {
      cursor_stack = make_stack(1)
    }

    local ok, error_message = plan_storage.export_plan_to_cursor(player, state)

    assert.is_false(ok)
    assert.are.equal("Split 'Starter Burners' has more linked blueprints than fit in one blueprint book.", error_message)
  end)

  it("replaces the existing in-save plan when importing a plan book", function()
    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Old Split")
    tracker.set_split_items(state, 1, {
      {name = "wood", count = 99}
    })
    state.current_split_index = 1
    state.editor_selection[5] = 1
    state.plan_source = "edited"

    local slot_count = 5
    local imported_book = make_stack(slot_count)
    assert.is_true(imported_book.set_stack({name = "blueprint-book"}))
    imported_book.label = "Imported Plan"
    imported_book.blueprint_description = [[format=long-pole-plan;version=1
plan_id=plan-imported
visibility=references-only
default_surface=gleba
]]

    local split_book = ensure_slot(imported_book.get_inventory(1), 1, slot_count)
    assert.is_true(split_book.set_stack({name = "blueprint-book"}))
    split_book.label = "Imported Split"
    split_book.blueprint_description = [[format=long-pole-split;version=1
surface=gleba

--- Extra Items ---
iron-gear-wheel=4

--- Technologies to Research ---
logistics

--- Notes ---
Imported notes.
]]

    local player = {
      cursor_stack = imported_book
    }

    local ok, error_message = plan_storage.import_plan_from_cursor(player, state)

    assert.is_true(ok)
    assert.is_nil(error_message)
    assert.are.equal("imported", state.plan_source)
    assert.are.equal("plan-imported", state.plan_id)
    assert.are.equal("Imported Plan", state.plan_name)
    assert.are.equal(1, state.current_split_index)
    assert.same({}, state.editor_selection)
    assert.are.equal(1, #state.splits)
    assert.are.equal("Imported Split", state.splits[1].name)
    assert.same({
      {name = "iron-gear-wheel", count = 4}
    }, state.splits[1].items)
    assert.same({
      {name = "logistics"}
    }, state.splits[1].technologies)
    assert.are.equal("Imported notes.", state.splits[1].notes)
  end)

  it("imports from a held blueprint library record as well as an item stack", function()
    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Old Split")

    local player = {
      cursor_stack = {
        valid_for_read = false
      },
      cursor_record = make_record({
        type = "blueprint-book",
        label = "Record Imported Plan",
        blueprint_description = [[format=long-pole-plan;version=1
plan_id=plan-record
visibility=references-only
default_surface=nauvis
]],
        contents = {
          [2] = make_record({
            type = "blueprint-book",
            label = "Record Split",
            blueprint_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
wood=3

--- Technologies to Research ---
automation

--- Notes ---
From record.
]]
          })
        }
      })
    }

    local ok, error_message = plan_storage.import_plan_from_cursor(player, state)

    assert.is_true(ok)
    assert.is_nil(error_message)
    assert.are.equal("Record Imported Plan", state.plan_name)
    assert.are.equal("plan-record", state.plan_id)
    assert.are.equal(1, #state.splits)
    assert.are.equal("Record Split", state.splits[1].name)
    assert.same({
      {name = "wood", count = 3}
    }, state.splits[1].items)
  end)

  it("imports the first Long Pole plan book found in the blueprint library", function()
    local state = {}
    tracker.init(state)

    local player = {
      blueprints = {
        [3] = make_record({
          type = "blueprint-book",
          label = "Ignore Me",
          blueprint_description = "not-a-long-pole-plan",
          contents = {}
        }),
        [7] = make_record({
          type = "blueprint-book",
          label = "Auto Imported Plan",
          blueprint_description = [[format=long-pole-plan;version=1
plan_id=auto-imported
visibility=references-only
default_surface=nauvis
]],
          contents = {
            [2] = make_record({
              type = "blueprint-book",
              label = "Auto Imported Split",
              blueprint_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
stone-furnace=1

--- Technologies to Research ---
automation

--- Notes ---
From auto import.
]]
            })
          }
        }),
        [9] = make_record({
          type = "blueprint-book",
          label = "Later Plan",
          blueprint_description = [[format=long-pole-plan;version=1
plan_id=later-plan
visibility=references-only
default_surface=nauvis
]],
          contents = {}
        })
      }
    }

    local ok, error_message = plan_storage.import_first_plan_from_blueprint_library(player, state)

    assert.is_true(ok)
    assert.is_nil(error_message)
    assert.are.equal("Auto Imported Plan", state.plan_name)
    assert.are.equal("auto-imported", state.plan_id)
    assert.are.equal(1, #state.splits)
    assert.are.equal("Auto Imported Split", state.splits[1].name)
  end)

  it("does not auto-import plan books from the game blueprint library", function()
    local state = {}
    tracker.init(state)

    local player = {
      blueprints = {}
    }
    local game_script = {
      blueprints = {
        [5] = make_record({
          type = "blueprint-book",
          label = "Shared Plans",
          contents = {
            [3] = make_record({
              type = "blueprint-book",
              label = "Shared Imported Plan",
              blueprint_description = [[format=long-pole-plan;version=1
plan_id=shared-plan
visibility=references-only
default_surface=nauvis
]],
              contents = {
                [1] = make_record({
                  type = "blueprint-book",
                  label = "Shared Imported Split",
                  blueprint_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
burner-mining-drill=2

--- Technologies to Research ---
automation

--- Notes ---
From shared library.
]]
                })
              }
            })
          }
        })
      }
    }

    local ok, error_message = plan_storage.import_first_plan_from_blueprint_library(player, state, game_script)

    assert.is_false(ok)
    assert.are.equal("No Long Pole plan book was found in the player blueprint library.", error_message)
    assert.is_nil(state.plan_id)
  end)

  it("recovers plan and split labels from exported record data when record labels are unavailable", function()
    with_mocked_label_imports({
      ["plan-record-export"] = "Recovered Record Plan",
      ["split-record-export"] = "Recovered Record Split"
    }, function()
      local state = {}
      tracker.init(state)
      plan_storage.create_new_plan(state)

      local player = {
        cursor_stack = {
          valid_for_read = false
        },
        cursor_record = make_record({
          type = "blueprint-book",
          export_string = "plan-record-export",
          blueprint_description = [[format=long-pole-plan;version=1
plan_id=plan-record-export
visibility=references-only
default_surface=nauvis
]],
          contents = {
            [1] = make_record({
              type = "blueprint-book",
              export_string = "split-record-export",
              blueprint_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
wood=5

--- Technologies to Research ---

--- Notes ---
Recovered from export.
]]
            })
          }
        })
      }

      local ok, error_message = plan_storage.import_plan_from_cursor(player, state)

      assert.is_true(ok)
      assert.is_nil(error_message)
      assert.are.equal("Recovered Record Plan", state.plan_name)
      assert.are.equal("Recovered Record Split", state.splits[1].name)
    end)
  end)
end)
