local plan_editor
local split_tracker

describe("plan_editor", function()
  local original_modules = {}
  local original_game
  local original_prototypes

  local TITLEBAR_NAME = "long_pole_plan_editor_titlebar"
  local CONTENT_NAME = "long_pole_plan_editor_content"
  local SPLIT_ROW_BODY_NAME = "long_pole_split_row_body"
  local SPLIT_ROW_NAME_ROW_NAME = "long_pole_split_name_row"
  local SPLIT_ROW_NOTES_DRAWER_NAME = "long_pole_split_notes_drawer"

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
      text = spec.text,
      items = spec.items,
      selected_index = spec.selected_index,
      tags = spec.tags,
      visible = spec.visible ~= false,
      enabled = spec.enabled ~= false,
      ignored_by_interaction = spec.ignored_by_interaction,
      children = {},
      _style = {},
      parent = nil,
      player_index = spec.player_index
    }

    function element.add(child_spec)
      child_spec.player_index = child_spec.player_index or element.player_index
      local child = make_element(child_spec)
      child.parent = element
      element.children[#element.children + 1] = child
      if child.name then
        element[child.name] = child
      end
      return child
    end

    function element.destroy()
      element.valid = false
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

  local function make_player_with_screen_gui()
    local screen_root = {
      children = {},
      player_index = 1
    }

    function screen_root.add(spec)
      spec.player_index = spec.player_index or screen_root.player_index
      local child = make_element(spec)
      child.parent = screen_root
      screen_root.children[#screen_root.children + 1] = child
      if child.name then
        screen_root[child.name] = child
      end
      return child
    end

    return {
      index = 1,
      display_resolution = {width = 1920, height = 1080},
      display_scale = 1,
      force = {name = "player"},
      gui = {
        screen = screen_root
      }
    }
  end

  before_each(function()
    original_modules["util.blueprint_entity_summary"] = package.loaded["util.blueprint_entity_summary"]
    original_modules["util.blueprint_fingerprint"] = package.loaded["util.blueprint_fingerprint"]
    original_modules["util.blueprint_library"] = package.loaded["util.blueprint_library"]
    original_modules["build_requirements"] = package.loaded["build_requirements"]
    original_modules["gui.item_quantity_dialog"] = package.loaded["gui.item_quantity_dialog"]
    original_modules["plan_storage"] = package.loaded["plan_storage"]
    original_modules["gui.slot_grid"] = package.loaded["gui.slot_grid"]
    original_modules["util.cursor_blueprint_source"] = package.loaded["util.cursor_blueprint_source"]
    original_modules["gui.plan_editor"] = package.loaded["gui.plan_editor"]

    package.loaded["util.blueprint_entity_summary"] = {
      summarize_entities = function()
        return {}
      end
    }
    package.loaded["util.blueprint_fingerprint"] = {
      extract_blueprint_fingerprint = function(blueprint, symlink)
        return {
          blueprint_name = blueprint.name,
          entity_summary = blueprint.entity_summary or {},
          entity_count = blueprint.entity_count or 0,
          blueprint_fingerprint = "stub-fingerprint",
          library_root = symlink and symlink.library_root or nil,
          inside_books = symlink and symlink.inside_books or nil,
          blueprint_slot = symlink and symlink.blueprint_slot or nil
        }
      end
    }
    package.loaded["util.blueprint_library"] = {
      find_blueprint_symlink_by_fingerprint = function()
        return {
          blueprint_name = "Recovered Library Name",
          library_root = "player-blueprints",
          inside_books = {"Openers"},
          blueprint_slot = 2,
          match_fraction = 1.0
        }
      end
    }
    package.loaded["build_requirements"] = {
      summarize_split = function()
        return {}
      end,
      summarize_raw_cost = function()
        return {}
      end
    }
    package.loaded["gui.item_quantity_dialog"] = {
      root_name = "long_pole_item_quantity_dialog",
      close = function() end,
      handle_click = function()
        return nil
      end,
      handle_text_changed = function()
        return false
      end,
      handle_elem_changed = function()
        return false
      end,
      handle_value_changed = function()
        return false
      end,
      handle_confirmed = function()
        return nil
      end,
      open = function() end
    }
    package.loaded["plan_storage"] = {
      export_plan_to_cursor = function()
        return true
      end
    }
    package.loaded["gui.slot_grid"] = {
      add = function(parent, _entries, _options)
        return parent.add({
          type = "flow",
          direction = "horizontal"
        })
      end,
      matches_action = function()
        return false
      end
    }
    package.loaded["util.cursor_blueprint_source"] = {
      resolve_selected_blueprint = function()
        return nil, "not needed in plan_editor_spec"
      end
    }

    package.loaded["gui.plan_editor"] = nil
    plan_editor = require("gui.plan_editor")
    split_tracker = require("split_tracker")

    original_game = rawget(_G, "game")
    original_prototypes = rawget(_G, "prototypes")
    _G.game = {
      tick = 0,
      get_player = function()
        return {
          print = function() end
        }
      end
    }
    _G.prototypes = {
      technology = {}
    }
  end)

  after_each(function()
    for module_name, module_value in pairs(original_modules) do
      package.loaded[module_name] = module_value
    end
    _G.game = original_game
    _G.prototypes = original_prototypes
  end)

  local function make_state()
    local state = {
      splits = {
        {
          id = 1,
          name = "Split 1",
          items = {},
          blueprints = {},
          technologies = {},
          notes = "",
          surface = "nauvis"
        }
      },
      plan_name = "Plan A",
      plan_id = "plan-a",
      plan_source = "none",
      editor_selection = {},
      current_split_index = 1,
      next_split_id = 2
    }
    split_tracker.init(state)
    return state
  end

  it("adds a held cursor record blueprint without reading label directly", function()
    local state = make_state()
    local printed_messages = {}
    local player = {
      index = 1,
      print = function(message)
        printed_messages[#printed_messages + 1] = message
      end,
      gui = {
        screen = {}
      }
    }

    package.loaded["util.cursor_blueprint_source"].resolve_selected_blueprint = function()
      return {
        carrier = "cursor_record",
        source = {
          export_record = function()
            return "record-blueprint-export"
          end,
          get_blueprint_entities = function()
            return {
              {name = "transport-belt"}
            }
          end,
          get_blueprint_entity_count = function()
            return 1
          end
        },
        source_book_label = "Openers",
        source_book_active_index = 2
      }, nil
    end

    local result = plan_editor.handle_click(player, state, {
      name = plan_editor.add_blueprint_button_name,
      tags = {
        split_id = state.splits[1].id
      }
    })

    assert.are.equal("refresh-split-viewer", result)
    assert.are.equal(0, #printed_messages)
    assert.are.equal(1, #state.splits[1].blueprints)
    assert.are.equal("stub-fingerprint", state.splits[1].blueprints[1].blueprint_fingerprint)
    assert.are.equal("Recovered Library Name", state.splits[1].blueprints[1].name)
    assert.are.equal("Openers", state.splits[1].blueprints[1].source_book_label)
    assert.are.equal(2, state.splits[1].blueprints[1].source_book_active_index)
  end)
end)
