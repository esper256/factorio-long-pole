local split_viewer = require("gui.split_viewer")
local progress_tracker_store = require("progress_tracker_store")

describe("split_viewer", function()
  local function make_element(spec)
    local element = {
      type = spec.type,
      valid = true,
      name = spec.name,
      caption = spec.caption,
      direction = spec.direction,
      tooltip = spec.tooltip,
      sprite = spec.sprite,
      number = spec.number,
      value = spec.value,
      visible = spec.visible ~= false,
      enabled = spec.enabled ~= false,
      quality = spec.quality,
      tags = spec.tags,
      children = {},
      _style = {},
      parent = nil
    }

    function element.add(child_spec)
      local child = make_element(child_spec)
      child.parent = element
      element.children[#element.children + 1] = child
      if child.name then
        element[child.name] = child
      end
      return child
    end

    function element.destroy()
      element.destroyed = true
      if element.parent and element.parent.children then
        for index, sibling in ipairs(element.parent.children) do
          if sibling == element then
            table.remove(element.parent.children, index)
            break
          end
        end
      end
      if element.parent and element.name and element.parent[element.name] == element then
        element.parent[element.name] = nil
      end
    end

    return setmetatable(element, {
      __index = function(target, key)
        if key == "style" then
          return rawget(target, "_style")
        end

        return rawget(target, key)
      end,
      __newindex = function(target, key, value)
        if key == "style" then
          rawset(target, "style_name", value)
          return
        end

        rawset(target, key, value)
      end
    })
  end

  local function make_player_with_left_gui()
    local left_root = {
      children = {}
    }

    function left_root.add(spec)
      local child = make_element(spec)
      child.parent = left_root
      left_root.children[#left_root.children + 1] = child
      if child.name then
        left_root[child.name] = child
      end
      return child
    end

    return {
      index = 1,
      force = {
        name = "player"
      },
      cursor_stack = {
        valid_for_read = false
      },
      gui = {
        left = left_root
      }
    }
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

  it("imports from a held blueprint library record without opening the editor", function()
    local opened_with_plan_name = nil
    local printed_message = nil
    local original_plan_editor = package.loaded["gui.plan_editor"]

    package.loaded["gui.plan_editor"] = {
      open = function(_player, state)
        opened_with_plan_name = state.plan_name
      end
    }

    package.loaded["gui.split_viewer"] = nil
    split_viewer = require("gui.split_viewer")

    with_mocked_label_imports({
      ["split-viewer-plan-export"] = "Imported From Record",
      ["split-viewer-split-export"] = "Imported Split"
    }, function()
      local player = {
        cursor_stack = {
          valid_for_read = false
        },
        cursor_record = {
          valid = true,
          type = "blueprint-book",
          export_record = function()
            return "split-viewer-plan-export"
          end,
          blueprint_description = [[format=long-pole-plan;version=1
plan_id=plan-click-import
visibility=references-only
default_surface=nauvis
]],
          contents = {
            [1] = {
              valid = true,
              type = "blueprint-book",
              export_record = function()
                return "split-viewer-split-export"
              end,
              blueprint_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
wood=2

--- Technologies to Research ---
automation

--- Notes ---
Imported from click.
]],
              contents = {}
            }
          },
          print = function(_, message)
            printed_message = message
          end
        }
      }
      player.print = function(_, message)
        printed_message = message
      end

      local state = {
        splits = {
          {
            id = 1,
            name = "Old Split",
            items = {},
            blueprints = {},
            technologies = {},
            notes = "",
            surface = "nauvis"
          }
        },
        plan_name = "Old Plan",
        plan_id = "old-plan",
        editor_selection = {},
        current_split_index = 1,
        next_split_id = 2
      }

      local handled = split_viewer.handle_click(player, state, {
        name = split_viewer.open_editor_button_name
      })

      assert.is_true(handled)
      assert.is_nil(printed_message)
      assert.are.equal("Imported From Record", state.plan_name)
      assert.are.equal("Imported Split", state.splits[1].name)
      assert.is_nil(opened_with_plan_name)
    end)

    package.loaded["gui.plan_editor"] = original_plan_editor
    package.loaded["gui.split_viewer"] = nil
  end)

  it("imports from a held blueprint book without opening the editor", function()
    local opened_with_plan_name = nil
    local printed_message = nil
    local original_plan_editor = package.loaded["gui.plan_editor"]
    local tracker = require("split_tracker")
    local plan_storage = require("plan_storage")

    package.loaded["gui.plan_editor"] = {
      open = function(_player, state)
        opened_with_plan_name = state.plan_name
      end
    }

    package.loaded["gui.split_viewer"] = nil
    split_viewer = require("gui.split_viewer")

    local state = {}
    tracker.init(state)
    plan_storage.create_new_plan(state)
    tracker.add_split(state, "Old Split")

    local function make_inventory(slot_count)
      local inventory = {}

      return setmetatable(inventory, {
        __len = function(table_self)
          return rawlen(table_self)
        end
      })
    end

    local function make_stack(slot_count)
      local stack = {
        valid_for_read = false,
        is_blueprint_book = false,
        label = nil,
        inventory = nil
      }

      function stack.clear()
        stack.valid_for_read = false
        stack.is_blueprint_book = false
        stack.label = nil
        stack.inventory = nil
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

        return false
      end

      function stack.get_inventory(_inventory_id)
        return stack.inventory
      end

      return stack
    end

    local function ensure_slot(inventory, slot_index, slot_count)
      while #inventory < slot_index do
        inventory[#inventory + 1] = make_stack(slot_count)
      end

      return inventory[slot_index]
    end

    local slot_count = 3
    local imported_book = make_stack(slot_count)
    assert.is_true(imported_book.set_stack({name = "blueprint-book"}))
    imported_book.label = "Imported Plan"
    imported_book.blueprint_description = [[format=long-pole-plan;version=1
plan_id=plan-imported
visibility=references-only
default_surface=nauvis
]]

    local split_book = ensure_slot(imported_book.get_inventory(1), 1, slot_count)
    assert.is_true(split_book.set_stack({name = "blueprint-book"}))
    split_book.label = "Imported Split"
    split_book.blueprint_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
wood=2

--- Technologies to Research ---
automation

--- Notes ---
Imported from item.
]]

    local player = {
      cursor_stack = imported_book
    }
    player.print = function(_, message)
      printed_message = message
    end

    local handled = split_viewer.handle_click(player, state, {
      name = split_viewer.open_editor_button_name
    })

    assert.is_true(handled)
    assert.is_nil(printed_message)
    assert.are.equal("Imported Plan", state.plan_name)
    assert.are.equal("Imported Split", state.splits[1].name)
    assert.is_nil(opened_with_plan_name)

    package.loaded["gui.plan_editor"] = original_plan_editor
    package.loaded["gui.split_viewer"] = nil
  end)

  it("renders the current split stopwatch on the far right and advances using the click tick", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      tick = 3600
    }

    local player = make_player_with_left_gui()
    local state = {
      splits = {
        {
          id = 1,
          name = "Current Split",
          items = {
            {name = "transport-belt", count = 10}
          },
          blueprints = {},
          technologies = {},
          notes = "",
          surface = "nauvis"
        },
        {
          id = 2,
          name = "Next Split",
          items = {},
          blueprints = {},
          technologies = {},
          notes = "",
          surface = "nauvis"
        }
      },
      editor_selection = {},
      current_split_index = 1,
      current_split_started_tick = 3480
    }

    split_viewer.refresh(player, state)

    local frame = player.gui.left[split_viewer.root_name]
    local body = frame.children[2]
    local current_row = body.children[1]
    local stopwatch_button = current_row.children[2]

    assert.are.equal(split_viewer.advance_split_button_name, stopwatch_button.name)
    assert.are.equal("00:02", stopwatch_button.caption)
    assert.are.equal("Current Split", current_row.children[1].caption)

    assert.is_true(split_viewer.handle_click(player, state, {
      name = split_viewer.advance_split_button_name
    }, {
      tick = 4200
    }))
    assert.are.equal(2, state.current_split_index)
    assert.are.equal(4200, state.current_split_started_tick)

    _G.game = previous_game
  end)

  it("shows completed split time as a label and leaves future split time blank", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      tick = 0
    }

    local player = make_player_with_left_gui()
    local state = {
      splits = {
        {
          id = 1,
          name = "Done Split",
          items = {},
          blueprints = {},
          technologies = {},
          notes = "",
          surface = "nauvis",
          completed_elapsed_ticks = 7500
        },
        {
          id = 2,
          name = "Current Split",
          items = {
            {name = "iron-gear-wheel", count = 5}
          },
          blueprints = {},
          technologies = {},
          notes = "",
          surface = "nauvis"
        },
        {
          id = 3,
          name = "Future Split",
          items = {
            {name = "transport-belt", count = 10}
          },
          blueprints = {},
          technologies = {},
          notes = "",
          surface = "nauvis"
        }
      },
      editor_selection = {},
      current_split_index = 2,
      current_split_started_tick = 0
    }

    split_viewer.refresh(player, state)

    local frame = player.gui.left[split_viewer.root_name]
    local body = frame.children[2]
    local completed_row = body.children[1]
    local future_row = body.children[3]

    assert.are.equal("Done Split", completed_row.children[1].caption)
    assert.are.equal("02:05", completed_row.children[2].caption)
    assert.are.equal("empty-widget", future_row.children[2].type)

    _G.game = previous_game
  end)

  it("toggles a compact progress popup from the splits title using icon slots and totals", function()
    local player = make_player_with_left_gui()
    local state = {
      splits = {
        {
          id = 4,
          name = "Current Split",
          items = {},
          blueprints = {},
          technologies = {},
          notes = "",
          surface = "nauvis"
        }
      },
      editor_selection = {},
      current_split_index = 1
    }

    progress_tracker_store.init(state)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "transport-belt", 25)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-chest", 3)
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 11,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "transport-belt",
      split_id = 4
    })
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 12,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "assembling-machine-1",
      split_id = 4
    })
    progress_tracker_store.set_loose_stock(state, "enemy", "nauvis", "firearm-magazine", 99)
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 13,
      force_name = "enemy",
      surface_name = "nauvis",
      item_name = "firearm-magazine",
      split_id = 4
    })

    split_viewer.refresh(player, state)
    local frame = player.gui.left[split_viewer.root_name]
    local header = frame.children[1]
    local title = header.children[2]
    assert.are.equal(split_viewer.title_toggle_button_name, title.name)
    assert.are.equal("Splits +", title.caption)

    assert.is_true(split_viewer.handle_click(player, state, title))

    split_viewer.refresh(player, state)

    frame = player.gui.left[split_viewer.root_name]
    header = frame.children[1]
    title = header.children[2]
    assert.are.equal("Splits -", title.caption)
    local popup = frame.children[3]
    local content = popup.children[1]
    local placed_section = content.children[1]
    local loose_section = content.children[2]
    local placed_grid = placed_section.children[2].children[1]
    local loose_grid = loose_section.children[2].children[1]

    assert.are.equal("Placed", placed_section.children[1].caption)
    assert.are.equal("Loose", loose_section.children[1].caption)
    assert.are.equal("item/assembling-machine-1", placed_grid.children[1].sprite)
    assert.are.equal(1, placed_grid.children[1].number)
    assert.are.equal("item/transport-belt", placed_grid.children[2].sprite)
    assert.are.equal(1, placed_grid.children[2].number)
    assert.are.equal("item/transport-belt", loose_grid.children[1].sprite)
    assert.are.equal(25, loose_grid.children[1].number)
    assert.are.equal("item/iron-chest", loose_grid.children[2].sprite)
    assert.are.equal(3, loose_grid.children[2].number)
    assert.are_not.equal("item/firearm-magazine", loose_grid.children[1].sprite)
    assert.are_not.equal("item/firearm-magazine", loose_grid.children[2].sprite)

    assert.is_true(split_viewer.handle_click(player, state, title))
    split_viewer.refresh(player, state)
    frame = player.gui.left[split_viewer.root_name]
    assert.are.equal(2, #frame.children)
  end)

  it("renders previous debt, current progress groups, and next readiness icons with overflow", function()
    local previous_game = rawget(_G, "game")
    local previous_prototypes = rawget(_G, "prototypes")
    local previous_settings = rawget(_G, "settings")
    _G.game = {
      tick = 600
    }
    _G.settings = {
      global = {
        ["long-pole-split-viewer-icon-limit"] = {
          value = 2
        }
      }
    }
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

    local player = make_player_with_left_gui()
    local state = {
      splits = {
        {
          id = 1,
          name = "Prep",
          items = {
            {name = "wood", count = 5}
          },
          blueprints = {},
          technologies = {},
          notes = "",
          surface = "nauvis",
          completed_elapsed_ticks = 300
        },
        {
          id = 2,
          name = "Current",
          items = {
            {name = "iron-chest", count = 2}
          },
          blueprints = {
            {
              entity_summary = {
                {name = "transport-belt", count = 4}
              }
            }
          },
          technologies = {
            {name = "automation"}
          },
          notes = "",
          surface = "nauvis"
        },
        {
          id = 3,
          name = "Next",
          items = {
            {name = "burner-mining-drill", count = 3},
            {name = "assembling-machine-1", count = 1}
          },
          blueprints = {
            {
              entity_summary = {
                {name = "transport-belt", count = 2}
              }
            }
          },
          technologies = {},
          notes = "",
          surface = "nauvis"
        }
      },
      editor_selection = {},
      current_split_index = 2,
      current_split_started_tick = 0
    }

    progress_tracker_store.init(state)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "transport-belt", 2)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-chest", 1)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "automation-science-pack", 1)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-plate", 20)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "copper-plate", 2)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "burner-mining-drill", 1)
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 101,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "transport-belt",
      split_id = 2
    })

    split_viewer.refresh(player, state)

    local frame = player.gui.left[split_viewer.root_name]
    local body = frame.children[2]
    local previous_row = body.children[1]
    local current_row = body.children[2]
    local next_row = body.children[3]

    local previous_groups = previous_row.children[3]
    local previous_group = previous_groups.children[1]
    assert.are.equal("item/wood", previous_group.children[1].children[1].sprite)
    assert.are.equal(5, previous_group.children[1].children[1].number)
    assert.are.same({r = 0.85, g = 0.25, b = 0.25}, previous_group.children[1].children[2].style.color)

    local current_groups = current_row.children[3]
    local found_placement = false
    for _, child in ipairs(current_groups.children) do
      if child.type == "flow" and child.children[1] and child.children[1].children[1] then
        local sprite = child.children[1].children[1].sprite
        local number = child.children[1].children[1].number
        if sprite == "item/transport-belt" and number == 3 then
          found_placement = true
        end
      end
    end
    assert.is_true(found_placement)

    local next_groups = next_row.children[3]
    local next_group = next_groups.children[1]
    assert.are.equal("item/transport-belt", next_group.children[1].children[1].sprite)
    assert.are.equal(2, next_group.children[1].children[1].number)
    assert.are.equal("item/assembling-machine-1", next_group.children[2].children[1].sprite)
    assert.are.equal("... +1", next_group.children[3].caption)

    _G.game = previous_game
    _G.prototypes = previous_prototypes
    _G.settings = previous_settings
  end)
end)
