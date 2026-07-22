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

    local player = {
      cursor_stack = {
        valid_for_read = false
      },
      cursor_record = {
        valid = true,
        type = "blueprint-book",
        blueprint_description = [[format=long-pole-plan;version=1
plan_id=plan-click-import
plan_name=Imported From Record
visibility=references-only
default_surface=nauvis
]],
        contents = {
          [1] = {
            valid = true,
            type = "blueprint-book",
            blueprint_description = [[format=long-pole-split;version=1
split_name=Imported Split
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
plan_name=Imported Plan
visibility=references-only
default_surface=nauvis
]]

    local split_book = ensure_slot(imported_book.get_inventory(1), 1, slot_count)
    assert.is_true(split_book.set_stack({name = "blueprint-book"}))
    split_book.label = "Imported Split"
    split_book.blueprint_description = [[format=long-pole-split;version=1
split_name=Imported Split
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

end)
