local tracker = require("split_tracker")
local plan_storage = require("plan_storage")
local progress_tracker_store = require("progress_tracker_store")
local build_requirements = require("build_requirements")

describe("split_tracker", function()
  local function initialized_state_with_plan()
    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Starter Burners")
    tracker.add_split(state, "First Power")
    return state
  end

  it("initializes a consistent empty state before a plan source loads data", function()
    local state = {}
    tracker.init(state)

    assert.is_table(state.inventory)
    assert.is_table(state.progress_tracker)
    assert.is_table(state.splits)
    assert.is_table(state.editor_selection)
    assert.are.equal(1, state.current_split_index)
    assert.are.equal(0, #state.splits)
  end)

  it("creates an empty active plan through the storage layer", function()
    local state = {}
    tracker.init(state)

    assert.is_true(plan_storage.create_new_plan(state))

    assert.are.equal("new", state.plan_source)
    assert.are.equal("Untitled Plan", state.plan_name)
    assert.are.equal(0, #state.splits)
    assert.is_false(plan_storage.has_active_plan(state))
  end)

  it("derives split viewer button state from active splits instead of a loaded flag", function()
    local state = {}
    tracker.init(state)

    local player_without_book = {
      cursor_stack = {
        valid_for_read = false
      }
    }
    local new_spec = plan_storage.entry_button_spec(player_without_book, state)
    assert.are.equal("new", new_spec.mode)
    assert.are.equal("✎", new_spec.caption)

    tracker.add_split(state, "Starter Burners")
    local edit_spec = plan_storage.entry_button_spec(player_without_book, state)
    assert.is_true(plan_storage.has_active_plan(state))
    assert.are.equal("edit", edit_spec.mode)
    assert.are.equal("✎", edit_spec.caption)

    local player_with_import_book = {
      cursor_stack = {
        valid_for_read = true,
        is_blueprint_book = true,
        blueprint_description = "format=long-pole-plan;version=1\nplan_id=import-me\nvisibility=references-only\ndefault_surface=nauvis\n"
      }
    }
    local import_spec = plan_storage.entry_button_spec(player_with_import_book, state)
    assert.are.equal("import", import_spec.mode)
    assert.are.equal("↓", import_spec.caption)

    local player_with_import_record = {
      cursor_stack = {
        valid_for_read = false
      },
      cursor_record = {
        valid = true,
        type = "blueprint-book",
        blueprint_description = "format=long-pole-plan;version=1\nplan_id=record-import\nvisibility=references-only\ndefault_surface=nauvis\n",
        contents = {}
      }
    }
    local record_import_spec = plan_storage.entry_button_spec(player_with_import_record, state)
    assert.are.equal("import", record_import_spec.mode)
    assert.are.equal("↓", record_import_spec.caption)
  end)

  it("allows export into an empty cursor or the active plan's own exported book", function()
    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)

    local empty_cursor = {
      valid_for_read = false
    }
    assert.is_true(plan_storage.can_export_to_cursor(empty_cursor, state))

    local matching_book = {
      valid_for_read = true,
      is_blueprint_book = true,
      blueprint_description = ("format=long-pole-plan;version=1\nplan_id=%s\nvisibility=references-only\ndefault_surface=nauvis\n"):format(state.plan_id)
    }
    assert.is_true(plan_storage.can_export_to_cursor(matching_book, state))

    local different_book = {
      valid_for_read = true,
      is_blueprint_book = true,
      blueprint_description = "format=long-pole-plan;version=1\nplan_id=different-plan\nvisibility=references-only\ndefault_surface=nauvis\n"
    }
    assert.is_false(plan_storage.can_export_to_cursor(different_book, state))
  end)

  it("advances through the plan and marks the final split complete", function()
    local state = initialized_state_with_plan()

    assert.is_true(tracker.advance_split(state))
    assert.are.equal(2, state.current_split_index)

    state.current_split_started_tick = 120
    assert.is_true(tracker.advance_split(state, 300))
    assert.are.equal(#state.splits + 1, state.current_split_index)
    assert.are.equal(180, state.splits[#state.splits].completed_elapsed_ticks)
  end)

  it("tracks elapsed ticks for the current split and resets when advancing", function()
    local state = initialized_state_with_plan()

    tracker.ensure_current_split_started(state, 0)
    assert.are.equal(300, tracker.current_split_elapsed_ticks(state, 300))
    assert.are.equal(0, state.current_split_started_tick)
    assert.are.equal(390, tracker.current_split_elapsed_ticks(state, 390))

    assert.is_true(tracker.advance_split(state, 390))
    assert.are.equal(2, state.current_split_index)
    assert.are.equal(390, state.current_split_started_tick)
    assert.are.equal(60, tracker.current_split_elapsed_ticks(state, 450))
    assert.are.equal(390, state.splits[1].completed_elapsed_ticks)
  end)

  it("marks the final split complete and leaves no current split", function()
    local state = initialized_state_with_plan()
    state.current_split_index = 2
    state.current_split_started_tick = 600

    assert.is_true(tracker.advance_split(state, 840))
    assert.are.equal(3, state.current_split_index)
    assert.is_nil(state.current_split_started_tick)
    assert.are.equal(240, state.splits[2].completed_elapsed_ticks)

    local status = tracker.get_split_status(state)
    assert.are.equal("First Power", status.previous.name)
    assert.are.equal(240, status.previous.completed_elapsed_ticks)
    assert.is_nil(status.current)
  end)

  it("adds and renames splits", function()
    local state = initialized_state_with_plan()

    local index, split = tracker.add_split(state, "Mall Setup")
    assert.are.equal("Mall Setup", split.name)

    assert.is_true(tracker.rename_split(state, index, "  Green Science  "))
    assert.are.equal("Green Science", state.splits[index].name)
  end)

  it("returns split status grouped around the current split", function()
    local state = initialized_state_with_plan()
    tracker.add_split(state, "Labs")
    state.current_split_index = 2

    local status = tracker.get_split_status(state)

    assert.are.equal("Starter Burners", status.previous.name)
    assert.are.equal("First Power", status.current.name)
    assert.are.equal("Labs", status.upcoming[1].name)
  end)

  it("only recalculates missing requirements for the current split views", function()
    local state = initialized_state_with_plan()
    tracker.add_split(state, "Labs")
    tracker.add_split(state, "Mall")
    state.current_split_index = 2

    local original_missing = build_requirements.summarize_missing_requirements
    local original_direct = build_requirements.summarize_direct_requirement_progress
    local calls = {}

    build_requirements.summarize_missing_requirements = function(split, _snapshot, options)
      calls[#calls + 1] = {
        split_name = split.name,
        include_blueprints = options and options.include_blueprints,
        include_items = options and options.include_items
      }
      return {}, nil, {}
    end
    build_requirements.summarize_direct_requirement_progress = function()
      return {}, nil, {}
    end

    local ok, result = pcall(function()
      return tracker.get_split_status(state, "player")
    end)

    build_requirements.summarize_missing_requirements = original_missing
    build_requirements.summarize_direct_requirement_progress = original_direct

    assert.is_true(ok)
    assert.is_table(result)
    assert.are.equal(3, #calls)
    assert.are.equal("First Power", calls[1].split_name)
    assert.is_nil(calls[1].include_blueprints)
    assert.is_nil(calls[1].include_items)
    assert.are.equal("First Power", calls[2].split_name)
    assert.is_false(calls[2].include_blueprints)
    assert.is_false(calls[2].include_items)
    assert.are.equal("Starter Burners", calls[3].split_name)
  end)

  it("reuses cached root requirements across repeated status refreshes", function()
    local state = initialized_state_with_plan()
    tracker.add_split(state, "Labs")
    state.current_split_index = 2

    local original_build_root_requirements = build_requirements.build_root_requirements
    local original_missing = build_requirements.summarize_missing_requirements
    local original_direct = build_requirements.summarize_direct_requirement_progress
    local build_root_call_count = 0

    build_requirements.build_root_requirements = function(split, options)
      build_root_call_count = build_root_call_count + 1
      return original_build_root_requirements(split, options)
    end
    build_requirements.summarize_missing_requirements = function(_split, _snapshot, _options)
      return {}, nil, {}
    end
    build_requirements.summarize_direct_requirement_progress = function(_split, _snapshot, _options)
      return {}, nil, {}
    end

    local ok, result = pcall(function()
      tracker.get_split_status(state, "player")
      tracker.get_split_status(state, "player")
      return true
    end)

    build_requirements.build_root_requirements = original_build_root_requirements
    build_requirements.summarize_missing_requirements = original_missing
    build_requirements.summarize_direct_requirement_progress = original_direct

    assert.is_true(ok)
    assert.is_true(result)
    assert.are.equal(5, build_root_call_count)
  end)

  it("derives current split missing intermediates from the tracked split snapshot", function()
    local previous_prototypes = rawget(_G, "prototypes")
    _G.prototypes = {
      entity = {
        ["transport-belt"] = {
          items_to_place_this = {
            {name = "transport-belt", count = 1}
          }
        }
      },
      recipe = {
        ["transport-belt"] = {
          ingredients = {
            {type = "item", name = "iron-plate", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 1}
          },
          products = {
            {type = "item", name = "transport-belt", amount = 2}
          }
        },
        ["iron-gear-wheel"] = {
          ingredients = {
            {type = "item", name = "iron-plate", amount = 2}
          },
          products = {
            {type = "item", name = "iron-gear-wheel", amount = 1}
          }
        }
      }
    }

    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Belts")
    assert.is_true(tracker.set_split_blueprints(state, 1, {
      {
        name = "Starter line",
        entity_summary = {
          {name = "transport-belt", count = 6}
        }
      }
    }))

    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "transport-belt", 2)
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 41,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "transport-belt",
      split_id = state.splits[1].id
    })
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 42,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "transport-belt",
      split_id = state.splits[1].id
    })

    local status = tracker.get_split_status(state, "player")
    local indexed = {}
    for _, entry in ipairs(status.current.missing) do
      indexed[entry.name] = entry
    end

    assert.are.equal(2, indexed["transport-belt"].count)
    assert.are.equal(1, indexed["iron-gear-wheel"].count)
    assert.are.equal(3, indexed["iron-plate"].count)

    _G.prototypes = previous_prototypes
  end)

  it("builds separate icon groups for previous debt, current placement and research, and next readiness", function()
    local previous_prototypes = rawget(_G, "prototypes")
    _G.prototypes = {
      entity = {
        ["transport-belt"] = {
          items_to_place_this = {
            {name = "transport-belt", count = 1}
          }
        }
      },
      technology = {
        automation = {
          research_unit_count = 2,
          research_unit_ingredients = {
            {name = "automation-science-pack", amount = 1}
          }
        }
      },
      recipe = {
        ["transport-belt"] = {
          ingredients = {
            {type = "item", name = "iron-plate", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 1}
          },
          products = {
            {type = "item", name = "transport-belt", amount = 2}
          }
        },
        ["iron-chest"] = {
          ingredients = {
            {type = "item", name = "iron-plate", amount = 8}
          },
          products = {
            {type = "item", name = "iron-chest", amount = 1}
          }
        },
        ["automation-science-pack"] = {
          ingredients = {
            {type = "item", name = "copper-plate", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 1}
          },
          products = {
            {type = "item", name = "automation-science-pack", amount = 1}
          }
        },
        ["iron-gear-wheel"] = {
          ingredients = {
            {type = "item", name = "iron-plate", amount = 2}
          },
          products = {
            {type = "item", name = "iron-gear-wheel", amount = 1}
          }
        }
      }
    }

    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Prep")
    tracker.add_split(state, "Current")
    tracker.add_split(state, "Next")

    state.splits[1].completed_elapsed_ticks = 300
    assert.is_true(tracker.set_split_items(state, 1, {
      {name = "wood", count = 5}
    }))
    assert.is_true(tracker.set_split_blueprints(state, 2, {
      {
        entity_summary = {
          {name = "transport-belt", count = 4}
        }
      }
    }))
    assert.is_true(tracker.set_split_items(state, 2, {
      {name = "iron-chest", count = 2}
    }))
    assert.is_true(tracker.set_split_technologies(state, 2, {
      {name = "automation"}
    }))
    assert.is_true(tracker.set_split_blueprints(state, 3, {
      {
        entity_summary = {
          {name = "transport-belt", count = 2}
        }
      }
    }))
    assert.is_true(tracker.set_split_items(state, 3, {
      {name = "burner-mining-drill", count = 3},
      {name = "assembling-machine-1", count = 1}
    }))
    state.current_split_index = 2

    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "transport-belt", 2)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-chest", 1)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "automation-science-pack", 1)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-plate", 20)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "copper-plate", 2)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "burner-mining-drill", 1)
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 91,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "transport-belt",
      split_id = state.splits[2].id
    })

    local status = tracker.get_split_status(state, "player")
    local previous_kinds = {}
    for _, group in ipairs(status.previous.icon_groups) do
      previous_kinds[group.kind] = group
    end
    local current_kinds = {}
    for _, group in ipairs(status.current.icon_groups) do
      current_kinds[group.kind] = group
    end

    assert.are.equal("previous-leftover", status.previous.icon_groups[1].kind)
    assert.are.equal("alert", status.previous.icon_groups[1].tone)
    assert.are.equal("wood", previous_kinds["previous-leftover"].entries[1].name)

    assert.is_not_nil(current_kinds["remaining-work"])
    assert.are.equal("eta", current_kinds["remaining-work"].sort_mode)
    assert.is_not_nil(current_kinds["placement-progress"])
    assert.are.equal("transport-belt", current_kinds["placement-progress"].entries[1].name)
    assert.are.equal(3, current_kinds["placement-progress"].entries[1].count)
    assert.is_not_nil(current_kinds["research-production"])

    assert.are.equal(1, #status.upcoming[1].icon_groups)
    assert.are.equal("next-split-readiness", status.upcoming[1].icon_groups[1].kind)

    _G.prototypes = previous_prototypes
  end)

  it("updates split fields and supports reordering", function()
    local state = initialized_state_with_plan()
    local first_id = state.splits[1].id

    assert.is_true(tracker.set_split_blueprints(state, 1, {
      {name = "Burner Opener"},
      {name = "Coal Line"}
    }))
    assert.is_true(tracker.set_split_items(state, 1, {
      {name = "iron-gear-wheel", count = 10}
    }))
    assert.is_true(tracker.set_split_technologies(state, 1, {
      {name = "automation"}
    }))
    assert.is_true(tracker.set_split_notes(state, 1, "Feed gears before circuits."))

    assert.are.equal("Burner Opener", state.splits[1].blueprints[1].name)
    assert.are.equal(10, state.splits[1].items[1].count)
    assert.are.equal("automation", state.splits[1].technologies[1].name)
    assert.are.equal("Feed gears before circuits.", state.splits[1].notes)

    assert.are.equal(1, tracker.find_split_index_by_id(state, first_id))
    assert.is_true(tracker.move_split(state, 1, 2))
    assert.are.equal("Starter Burners", state.splits[2].name)
    assert.are.equal(2, tracker.find_split_index_by_id(state, first_id))
  end)

  it("removes splits and keeps current and selected indexes aligned", function()
    local state = initialized_state_with_plan()
    tracker.add_split(state, "Labs")
    state.current_split_index = 2
    state.editor_selection[1] = 3
    state.editor_selection[2] = 2

    assert.is_true(tracker.remove_split(state, 2))

    assert.are.equal(2, #state.splits)
    assert.are.equal("Starter Burners", state.splits[1].name)
    assert.are.equal("Labs", state.splits[2].name)
    assert.are.equal(2, state.current_split_index)
    assert.are.equal(2, state.editor_selection[1])
    assert.are.equal(2, state.editor_selection[2])
  end)

  it("removes the final split by id and clears stale editor selection", function()
    local state = initialized_state_with_plan()
    local second_id = state.splits[2].id
    state.current_split_index = 2
    state.editor_selection[1] = 2

    assert.is_true(tracker.remove_split_by_id(state, second_id))

    assert.are.equal(1, #state.splits)
    assert.are.equal("Starter Burners", state.splits[1].name)
    assert.are.equal(1, state.current_split_index)
    assert.are.equal(1, state.editor_selection[1])

    assert.is_true(tracker.remove_split(state, 1))
    assert.are.equal(0, #state.splits)
    assert.are.equal(1, state.current_split_index)
    assert.is_nil(state.editor_selection[1])
  end)

  it("stores a surface per split", function()
    local state = initialized_state_with_plan()
    local split_id = state.splits[1].id

    assert.are.equal("nauvis", state.splits[1].surface)
    assert.is_true(tracker.set_split_surface_by_id(state, split_id, "gleba"))
    assert.are.equal("gleba", state.splits[1].surface)
  end)

  it("supports blueprint linking and item picker style updates", function()
    local state = initialized_state_with_plan()
    local split_id = state.splits[1].id

    assert.is_true(tracker.add_split_blueprint_by_id(state, split_id, {
      name = "Starter burner pair",
      export_string = "blueprint-data",
      entity_count = 4,
      entity_summary = {
        {name = "burner-mining-drill", count = 2},
        {name = "stone-furnace", count = 2}
      }
    }))
    assert.are.equal(1, #state.splits[1].blueprints)
    assert.are.equal(2, state.splits[1].blueprints[1].entity_summary[1].count)

    assert.is_true(tracker.replace_split_blueprint_by_id(state, split_id, 1, {
      name = "Starter burner pair v2",
      export_string = "blueprint-data-v2",
      entity_count = 5,
      entity_summary = {
        {name = "burner-mining-drill", count = 3},
        {name = "stone-furnace", count = 2}
      }
    }))
    assert.are.equal("Starter burner pair v2", state.splits[1].blueprints[1].name)
    assert.are.equal("burner-mining-drill", state.splits[1].blueprints[1].entity_summary[1].name)

    assert.is_true(tracker.add_split_item_by_id(state, split_id, {count = 1}))
    assert.is_true(tracker.set_split_item_name_by_id(state, split_id, 1, "transport-belt"))
    assert.is_true(tracker.set_split_item_count_by_id(state, split_id, 1, "200"))
    assert.are.equal("transport-belt", state.splits[1].items[1].name)
    assert.are.equal(200, state.splits[1].items[1].count)

    assert.is_true(tracker.replace_split_item_by_id(state, split_id, 1, {
      name = "iron-chest",
      count = 3.8
    }))
    assert.are.equal("iron-chest", state.splits[1].items[1].name)
    assert.are.equal(3, state.splits[1].items[1].count)

    assert.is_true(tracker.remove_split_blueprint_by_id(state, split_id, 1))
    assert.are.equal(0, #state.splits[1].blueprints)

    assert.is_true(tracker.remove_split_item_by_id(state, split_id, 1))
    assert.are.equal(0, #state.splits[1].items)
  end)

  it("supports adding and removing unique technologies by id", function()
    local state = initialized_state_with_plan()
    local split_id = state.splits[1].id

    assert.is_true(tracker.add_split_technology_by_id(state, split_id, {
      name = "automation"
    }))
    assert.is_false(tracker.add_split_technology_by_id(state, split_id, {
      name = "automation"
    }))
    assert.are.equal("automation", state.splits[1].technologies[1].name)

    assert.is_true(tracker.remove_split_technology_by_id(state, split_id, 1))
    assert.are.equal(0, #state.splits[1].technologies)
  end)

  it("removes an item when a replacement omits the name", function()
    local state = initialized_state_with_plan()
    local split_id = state.splits[1].id

    assert.is_true(tracker.add_split_item_by_id(state, split_id, {
      name = "transport-belt",
      count = 5
    }))
    assert.is_true(tracker.replace_split_item_by_id(state, split_id, 1, {
      count = 10
    }))

    assert.are.equal(0, #state.splits[1].items)
  end)

  it("rewinds to the previous split without requiring completion", function()
    local state = initialized_state_with_plan()
    state.current_split_started_tick = 100
    assert.is_true(tracker.advance_split(state, 280))
    assert.are.equal(2, state.current_split_index)
    assert.are.equal(180, state.splits[1].completed_elapsed_ticks)

    assert.is_true(tracker.rewind_split(state, 400))
    assert.are.equal(1, state.current_split_index)
    assert.is_nil(state.splits[1].completed_elapsed_ticks)
    assert.are.equal(400, state.current_split_started_tick)
    assert.is_false(tracker.rewind_split(state, 410))
  end)

  it("resets the progress ledger when a new plan is imported", function()
    local state = initialized_state_with_plan()
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-plate", 20)
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 9,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "stone-furnace",
      split_id = state.splits[1].id
    })

    local source = {
      valid = true,
      type = "blueprint-book",
      label = "Imported",
      blueprint_description = "format=long-pole-plan;version=1\nplan_id=new-plan\nvisibility=references-only\ndefault_surface=nauvis\n",
      contents = {
        [1] = {
          valid = true,
          type = "blueprint-book",
          label = "Fresh Split",
          blueprint_description = "format=long-pole-split;version=1\nsurface=nauvis\n\n--- Extra Items ---\n\n--- Technologies to Research ---\n\n--- Notes ---\n",
          contents = {}
        }
      }
    }

    assert.is_true(plan_storage.import_plan_from_source(source, state))
    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-plate"))
    assert.are.equal(0, progress_tracker_store.get_placed_count(state, "player", "nauvis", "stone-furnace"))
    assert.are.equal("Fresh Split", state.splits[1].name)
  end)
end)
