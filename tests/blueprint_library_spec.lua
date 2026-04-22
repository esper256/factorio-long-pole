local blueprint_library = require("util.blueprint_library")

describe("blueprint_library", function()
  local function blueprint(entity_summary, label)
    local record = {
      valid = true,
      type = "blueprint",
      label = label
    }

    function record:is_blueprint_setup()
      return true
    end

    function record:get_blueprint_entities()
      local entities = {}
      local entity_number = 1
      for _, entry in ipairs(entity_summary or {}) do
        for _ = 1, entry.count do
          entities[#entities + 1] = {
            entity_number = entity_number,
            name = entry.name,
            position = {x = entity_number, y = 0}
          }
          entity_number = entity_number + 1
        end
      end
      return entities
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
        [7] = blueprint({{name = "transport-belt", count = 12}, {name = "inserter", count = 4}}, "Direct Blueprint")
      }
    }

    local match = blueprint_library.find_blueprint_symlink_by_fingerprint(player, {
      blueprint_fingerprint = "transport-belt:12;inserter:4",
      library_root = "player-blueprints"
    })

    assert.same({
      blueprint_name = "Direct Blueprint",
      library_root = "player-blueprints",
      inside_books = {},
      blueprint_slot = 7,
      match_fraction = 1.0
    }, match)
  end)

  it("finds the first exact match recursively through nested books", function()
    local player = {
      blueprints = {
        [1] = blueprint_book("Any% Openers", {
          [3] = blueprint_book("Burner Starts", {
            [2] = blueprint({{name = "burner-mining-drill", count = 2}, {name = "stone-furnace", count = 2}}, "Starter burner pair")
          })
        }),
        [2] = blueprint_book("Other", {
          [1] = blueprint({{name = "burner-mining-drill", count = 2}, {name = "stone-furnace", count = 2}}, "Duplicate")
        })
      }
    }

    local match = blueprint_library.find_blueprint_symlink_by_fingerprint(player, {
      blueprint_fingerprint = "burner-mining-drill:2;stone-furnace:2",
      library_root = "player-blueprints",
      inside_books = {"Any% Openers", "Burner Starts"},
      blueprint_slot = 2
    })

    assert.same({
      blueprint_name = "Starter burner pair",
      library_root = "player-blueprints",
      inside_books = {"Any% Openers", "Burner Starts"},
      blueprint_slot = 2,
      match_fraction = 1.0
    }, match)
  end)

  it("falls back to game blueprints if the player library does not contain a match", function()
    local player = {
      blueprints = {}
    }
    local game_script = {
      blueprints = {
        [4] = blueprint_book("Shared", {
          [6] = blueprint({{name = "transport-belt", count = 12}, {name = "inserter", count = 4}}, "Shared Blueprint")
        })
      }
    }

    local match = blueprint_library.find_blueprint_symlink_by_fingerprint(player, {
      blueprint_fingerprint = "transport-belt:12;inserter:4",
      library_root = "game-blueprints",
      inside_books = {"Shared"},
      blueprint_slot = 6
    }, game_script)

    assert.same({
      blueprint_name = "Shared Blueprint",
      library_root = "game-blueprints",
      inside_books = {"Shared"},
      blueprint_slot = 6,
      match_fraction = 1.0
    }, match)
  end)

  it("handles unlabeled nested books without crashing", function()
    local player = {
      blueprints = {
        [1] = unlabeled_blueprint_book({
          [4] = blueprint({{name = "transport-belt", count = 12}, {name = "inserter", count = 4}}, "Nested Blueprint")
        })
      }
    }

    local match = blueprint_library.find_blueprint_symlink_by_fingerprint(player, {
      blueprint_fingerprint = "transport-belt:12;inserter:4",
      library_root = "player-blueprints",
      inside_books = {"Missing"},
      blueprint_slot = 4
    })

    assert.same({
      blueprint_name = "Nested Blueprint",
      library_root = "player-blueprints",
      inside_books = {},
      blueprint_slot = 4,
      match_fraction = 1.0
    }, match)
  end)

  it("finds the first matching blueprint book in player blueprints", function()
    local player = {
      blueprints = {
        [2] = blueprint_book("Openers", {
          [4] = blueprint_book("Candidate Plan", {
            [1] = blueprint("not-used", "Ignored Child")
          })
        }),
        [5] = blueprint_book("Later Plan", {})
      }
    }

    local match = blueprint_library.find_first_player_blueprint_book_matching(player, function(record)
      return record.type == "blueprint-book" and record.label == "Candidate Plan"
    end)

    assert.same({
      record = player.blueprints[2].contents[4],
      library_root = "player-blueprints",
      inside_books = {"Openers"},
      slot = 4
    }, match)
  end)

  it("falls back to game blueprint books when the player shelf has no match", function()
    local player = {
      blueprints = {}
    }
    local game_script = {
      blueprints = {
        [8] = blueprint_book("Shared Plans", {
          [1] = blueprint_book("Game Plan", {})
        })
      }
    }

    local match = blueprint_library.find_first_blueprint_book_matching(player, game_script, function(record)
      return record.type == "blueprint-book" and record.label == "Game Plan"
    end)

    assert.same({
      record = game_script.blueprints[8].contents[1],
      library_root = "game-blueprints",
      inside_books = {"Shared Plans"},
      slot = 1
    }, match)
  end)
end)
