local blueprint_library = require("blueprint_library")

describe("blueprint_library", function()
  local function blueprint(export_string, label)
    local record = {
      valid = true,
      type = "blueprint",
      label = label
    }

    function record:is_blueprint_setup()
      return true
    end

    function record:export_record()
      return export_string
    end

    return record
  end

  local function blueprint_book(label, contents)
    return {
      valid = true,
      type = "blueprint-book",
      label = label,
      contents = contents
    }
  end

  local function unlabeled_blueprint_book(contents)
    local record = {
      valid = true,
      type = "blueprint-book",
      contents = contents
    }

    return setmetatable(record, {
      __index = function(table_self, key)
        if key == "label" then
          error("LuaRecord doesn't contain key label.")
        end
        return rawget(table_self, key)
      end
    })
  end

  it("finds a blueprint directly in the player library root", function()
    local player = {
      blueprints = {
        [7] = blueprint("target", "Direct Blueprint")
      }
    }

    local match = blueprint_library.find_blueprint_path_by_export(player, "target")

    assert.same({
      library_root = "player-blueprints",
      inside_books = {},
      blueprint_slot = 7
    }, match)
  end)

  it("finds the first exact match recursively through nested books", function()
    local player = {
      blueprints = {
        [1] = blueprint_book("Any% Openers", {
          [3] = blueprint_book("Burner Starts", {
            [2] = blueprint("target", "Starter burner pair")
          })
        }),
        [2] = blueprint_book("Other", {
          [1] = blueprint("target", "Duplicate")
        })
      }
    }

    local match = blueprint_library.find_blueprint_path_by_export(player, "target")

    assert.same({
      library_root = "player-blueprints",
      inside_books = {"Any% Openers", "Burner Starts"},
      blueprint_slot = 2
    }, match)
  end)

  it("falls back to game blueprints if the player library does not contain a match", function()
    local player = {
      blueprints = {}
    }
    local game_script = {
      blueprints = {
        [4] = blueprint_book("Shared", {
          [6] = blueprint("target", "Shared Blueprint")
        })
      }
    }

    local match = blueprint_library.find_blueprint_path_by_export(player, "target", game_script)

    assert.same({
      library_root = "game-blueprints",
      inside_books = {"Shared"},
      blueprint_slot = 6
    }, match)
  end)

  it("handles unlabeled nested books without crashing", function()
    local player = {
      blueprints = {
        [1] = unlabeled_blueprint_book({
          [4] = blueprint("target", "Nested Blueprint")
        })
      }
    }

    local match = blueprint_library.find_blueprint_path_by_export(player, "target")

    assert.same({
      library_root = "player-blueprints",
      inside_books = {},
      blueprint_slot = 4
    }, match)
  end)
end)
