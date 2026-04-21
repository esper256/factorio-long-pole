local split_viewer = require("gui.split_viewer")

describe("split_viewer", function()
  local function make_element(spec)
    local element = {
      type = spec.type,
      name = spec.name,
      caption = spec.caption,
      direction = spec.direction,
      tooltip = spec.tooltip,
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

  it("imports from a held blueprint library record when the main button is clicked", function()
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
      assert.are.equal("Imported From Record", opened_with_plan_name)
    end)

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
end)
