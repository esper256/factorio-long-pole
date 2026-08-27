local progress_snooper = require("progress_snooper")
local progress_tracker_store = require("progress_tracker_store")

describe("progress_snooper", function()
  it("initializes modular snooper state separately from tracked progress data", function()
    local state = {}
    progress_tracker_store.init(state)

    local snooper_state = progress_snooper.init(state)

    assert.is_table(snooper_state)
    assert.is_table(snooper_state.enabled_snoopers)
    assert.is_true(snooper_state.enabled_snoopers["player-built-entity"])
    assert.is_true(snooper_state.enabled_snoopers["hand-crafting"])
    assert.is_true(snooper_state.enabled_snoopers["player-mined-entity"])
    assert.is_true(snooper_state.enabled_snoopers["production-statistics"])
    assert.is_true(snooper_state.enabled_snoopers["entity-lifetime"])
    assert.is_true(snooper_state.enabled_snoopers["research-progress"])
    assert.are.same({
      "on_built_entity",
      "on_entity_died",
      "on_object_destroyed",
      "on_player_cancelled_crafting",
      "on_player_crafted_item",
      "on_player_mined_entity",
      "on_pre_player_crafted_item",
      "on_robot_built_entity",
      "on_robot_mined_entity",
      "script_raised_destroy"
    }, progress_snooper.subscribed_event_names())
  end)

  it("routes player-built entity events through the built-entity snooper and consumes loose stock", function()
    local state = {
      splits = {
        {
          id = 41,
          surface = "nauvis"
        }
      },
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "transport-belt", 5)

    assert.is_true(progress_snooper.dispatch(state, "on_built_entity", {
      tick = 180,
      item_name = "transport-belt",
      consumed_items = {
        [1] = {
          valid_for_read = true,
          name = "transport-belt",
          count = 1
        }
      },
      created_entity = {
        valid = true,
        unit_number = 9001,
        name = "transport-belt",
        force = {
          name = "player"
        },
        surface = {
          name = "nauvis"
        }
      }
    }))

    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "player", "nauvis", "transport-belt"))
    assert.are.equal(4, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "transport-belt"))
    local snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis", 41)
    assert.are.same({
      item_name = "transport-belt",
      loose_stock = 4,
      placed_count = 1,
      current_split_claim = 1,
      produced_total = 0,
      consumed_total = 0,
      produced_rate = 0,
      consumed_rate = 0
    }, snapshot.entries[1])
  end)

  it("falls back to prototype placement items when the event does not name the item", function()
    local state = {
      splits = {
        {
          id = 52,
          surface = "nauvis"
        }
      },
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)

    assert.is_true(progress_snooper.dispatch(state, "on_built_entity", {
      tick = 240,
      created_entity = {
        valid = true,
        unit_number = 77,
        name = "stone-furnace",
        force = {
          name = "player"
        },
        surface_name = "nauvis",
        prototype = {
          items_to_place_this = {
            {name = "stone-furnace"}
          }
        }
      }
    }))

    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "player", "nauvis", "stone-furnace"))
  end)

  it("ignores untrackable built entities cleanly", function()
    local state = {
      splits = {},
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)

    assert.is_false(progress_snooper.dispatch(state, "on_built_entity", {
      tick = 10,
      created_entity = {
        valid = true,
        name = "straight-rail",
        force = {
          name = "player"
        },
        surface_name = "nauvis"
      }
    }))
  end)

  it("keeps different forces separate even on the same surface", function()
    local state = {
      splits = {
        {
          id = 61,
          surface = "nauvis"
        }
      },
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)

    assert.is_true(progress_snooper.dispatch(state, "on_built_entity", {
      tick = 300,
      item_name = "transport-belt",
      created_entity = {
        valid = true,
        unit_number = 500,
        name = "transport-belt",
        force = {
          name = "enemy"
        },
        surface = {
          name = "nauvis"
        }
      }
    }))

    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "enemy", "nauvis", "transport-belt"))
    assert.are.equal(0, progress_tracker_store.get_placed_count(state, "player", "nauvis", "transport-belt"))
  end)

  it("tracks construction robot builds and consumes the used item from loose stock", function()
    local state = {
      splits = {
        {
          id = 71,
          surface = "nauvis"
        }
      },
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "stone-furnace", 3)

    assert.is_true(progress_snooper.dispatch(state, "on_robot_built_entity", {
      tick = 360,
      stack = {
        name = "stone-furnace",
        count = 1
      },
      entity = {
        valid = true,
        unit_number = 700,
        name = "stone-furnace",
        force = {
          name = "player"
        },
        surface = {
          name = "nauvis"
        }
      }
    }))

    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "player", "nauvis", "stone-furnace"))
    assert.are.equal(2, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "stone-furnace"))
  end)

  it("tracks hand crafting ingredient consumption and product creation", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      get_player = function(player_index)
        if player_index ~= 1 then
          return nil
        end

        return {
          force = {
            name = "player"
          },
          surface = {
            name = "nauvis"
          }
        }
      end
    }

    local state = {
      splits = {},
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)

    assert.is_true(progress_snooper.dispatch(state, "on_pre_player_crafted_item", {
      player_index = 1,
      queued_count = 2,
      items = {
        [1] = {
          valid_for_read = true,
          name = "iron-plate",
          count = 4
        },
        [2] = {
          valid_for_read = true,
          name = "copper-cable",
          count = 6
        }
      }
    }))

    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-plate"))
    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "copper-cable"))

    assert.is_true(progress_snooper.dispatch(state, "on_player_crafted_item", {
      player_index = 1,
      item_stack = {
        name = "electronic-circuit",
        count = 2
      }
    }))

    assert.are.equal(2, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "electronic-circuit"))

    _G.game = previous_game
  end)

  it("polls item production statistics and applies automated production deltas", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      forces = {
        {
          name = "player",
          get_item_production_statistics = function(surface)
            if surface.name ~= "nauvis" then
              return {
                input_counts = {},
                output_counts = {}
              }
            end

            return {
              input_counts = {
                ["iron-gear-wheel"] = 6
              },
              output_counts = {
                ["iron-plate"] = 4
              }
            }
          end
        }
      },
      surfaces = {
        {
          name = "nauvis"
        }
      }
    }

    local state = {
      splits = {
        {
          id = 91,
          surface = "nauvis"
        }
      },
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-plate", 10)

    assert.is_true(progress_snooper.poll(state, _G.game))
    assert.are.equal(6, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-plate"))
    assert.are.equal(6, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-gear-wheel"))

    local snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis", 91)
    assert.are.same({
      item_name = "iron-gear-wheel",
      loose_stock = 6,
      placed_count = 0,
      current_split_claim = 0,
      produced_total = 6,
      consumed_total = 0,
      produced_rate = 0,
      consumed_rate = 0
    }, snapshot.entries[1])
    assert.are.same({
      item_name = "iron-plate",
      loose_stock = 6,
      placed_count = 0,
      current_split_claim = 0,
      produced_total = 0,
      consumed_total = 4,
      produced_rate = 0,
      consumed_rate = 0
    }, snapshot.entries[2])

    _G.game = previous_game
  end)

  it("excludes hand-crafted outputs from polled production statistics", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      get_player = function(player_index)
        if player_index ~= 1 then
          return nil
        end

        return {
          force = {
            name = "player"
          },
          surface = {
            name = "nauvis"
          }
        }
      end,
      forces = {
        {
          name = "player",
          get_item_production_statistics = function()
            return {
              input_counts = {
                ["copper-cable"] = 1
              },
              output_counts = {}
            }
          end
        }
      },
      surfaces = {
        {
          name = "nauvis"
        }
      }
    }

    local state = {
      splits = {},
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)

    assert.is_true(progress_snooper.dispatch(state, "on_player_crafted_item", {
      player_index = 1,
      item_stack = {
        name = "copper-cable",
        count = 1
      }
    }))

    assert.is_true(progress_snooper.poll(state, _G.game))
    assert.are.equal(1, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "copper-cable"))
    local produced_total, consumed_total = progress_tracker_store.get_production_totals(state, "player", "nauvis", "copper-cable")
    assert.are.equal(0, produced_total)
    assert.are.equal(0, consumed_total)

    _G.game = previous_game
  end)

  it("excludes manually mined resource outputs from polled production statistics", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      get_player = function(player_index)
        if player_index ~= 2 then
          return nil
        end

        return {
          force = {
            name = "player"
          },
          surface = {
            name = "nauvis"
          }
        }
      end,
      forces = {
        {
          name = "player",
          get_item_production_statistics = function()
            return {
              input_counts = {
                ["iron-ore"] = 3
              },
              output_counts = {}
            }
          end
        }
      },
      surfaces = {
        {
          name = "nauvis"
        }
      }
    }

    local state = {
      splits = {},
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)

    assert.is_true(progress_snooper.dispatch(state, "on_player_mined_entity", {
      player_index = 2,
      entity = {
        valid = true,
        type = "resource",
        name = "iron-ore",
        force = {
          name = "neutral"
        },
        surface = {
          name = "nauvis"
        }
      },
      buffer = {
        [1] = {
          valid_for_read = true,
          name = "iron-ore",
          count = 3
        }
      }
    }))

    assert.is_true(progress_snooper.poll(state, _G.game))
    assert.are.equal(3, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-ore"))
    local produced_total, consumed_total = progress_tracker_store.get_production_totals(state, "player", "nauvis", "iron-ore")
    assert.are.equal(0, produced_total)
    assert.are.equal(0, consumed_total)

    _G.game = previous_game
  end)

  it("returns cancelled hand crafting ingredients to loose stock", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      get_player = function(player_index)
        if player_index ~= 1 then
          return nil
        end

        return {
          force = {
            name = "player"
          },
          surface = {
            name = "nauvis"
          }
        }
      end
    }

    local state = {
      splits = {},
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)

    assert.is_true(progress_snooper.dispatch(state, "on_player_cancelled_crafting", {
      player_index = 1,
      cancel_count = 1,
      items = {
        [1] = {
          valid_for_read = true,
          name = "iron-plate",
          count = 3
        }
      }
    }))

    assert.are.equal(3, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-plate"))

    _G.game = previous_game
  end)

  it("tracks manual mining results from the mined-entity buffer", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      get_player = function(player_index)
        if player_index ~= 2 then
          return nil
        end

        return {
          force = {
            name = "player"
          },
          surface = {
            name = "nauvis"
          }
        }
      end
    }

    local state = {
      splits = {},
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)

    assert.is_true(progress_snooper.dispatch(state, "on_player_mined_entity", {
      player_index = 2,
      entity = {
        valid = true,
        name = "tree-01",
        force = {
          name = "neutral"
        },
        surface = {
          name = "nauvis"
        }
      },
      buffer = {
        [1] = {
          valid_for_read = true,
          name = "wood",
          count = 4
        },
        [2] = {
          valid_for_read = true,
          name = "raw-fish",
          count = 1
        }
      }
    }))

    assert.are.equal(4, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "wood"))
    assert.are.equal(1, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "raw-fish"))

    _G.game = previous_game
  end)

  it("removes mined entities from placed progress so replace-in-correct-spot is not double counted", function()
    local previous_game = rawget(_G, "game")
    _G.game = {
      get_player = function(player_index)
        if player_index ~= 2 then
          return nil
        end

        return {
          force = {
            name = "player"
          },
          surface = {
            name = "nauvis"
          }
        }
      end
    }

    local state = {
      splits = {
        {
          id = 81,
          surface = "nauvis"
        }
      },
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "stone-furnace", 1)

    assert.is_true(progress_snooper.dispatch(state, "on_built_entity", {
      tick = 400,
      item_name = "stone-furnace",
      consumed_items = {
        [1] = {
          valid_for_read = true,
          name = "stone-furnace",
          count = 1
        }
      },
      created_entity = {
        valid = true,
        unit_number = 8801,
        name = "stone-furnace",
        force = {
          name = "player"
        },
        surface = {
          name = "nauvis"
        }
      }
    }))

    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "player", "nauvis", "stone-furnace"))
    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "stone-furnace"))

    assert.is_true(progress_snooper.dispatch(state, "on_player_mined_entity", {
      player_index = 2,
      entity = {
        valid = true,
        unit_number = 8801,
        name = "stone-furnace",
        force = {
          name = "player"
        },
        surface = {
          name = "nauvis"
        }
      },
      buffer = {
        [1] = {
          valid_for_read = true,
          name = "stone-furnace",
          count = 1
        }
      }
    }))

    assert.are.equal(0, progress_tracker_store.get_placed_count(state, "player", "nauvis", "stone-furnace"))
    assert.are.equal(1, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "stone-furnace"))

    assert.is_true(progress_snooper.dispatch(state, "on_built_entity", {
      tick = 420,
      item_name = "stone-furnace",
      consumed_items = {
        [1] = {
          valid_for_read = true,
          name = "stone-furnace",
          count = 1
        }
      },
      created_entity = {
        valid = true,
        unit_number = 8802,
        name = "stone-furnace",
        force = {
          name = "player"
        },
        surface = {
          name = "nauvis"
        }
      }
    }))

    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "player", "nauvis", "stone-furnace"))
    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "stone-furnace"))

    _G.game = previous_game
  end)

  it("un-places destroyed entities and honors enabled_snoopers", function()
    local state = {
      splits = {
        {
          id = 81,
          surface = "nauvis"
        }
      },
      current_split_index = 1
    }
    progress_tracker_store.init(state)
    progress_snooper.init(state)
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 8801,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "stone-furnace",
      split_id = 81
    })

    assert.is_true(progress_snooper.dispatch(state, "on_entity_died", {
      tick = 500,
      entity = {
        valid = true,
        unit_number = 8801,
        name = "stone-furnace",
        type = "furnace",
        force = {name = "player"},
        surface = {name = "nauvis"}
      }
    }))
    assert.are.equal(0, progress_tracker_store.get_placed_count(state, "player", "nauvis", "stone-furnace"))

    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 8802,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "stone-furnace",
      split_id = 81
    })
    state.progress_snooper.enabled_snoopers["entity-lifetime"] = false
    assert.is_false(progress_snooper.dispatch(state, "on_object_destroyed", {
      useful_id = 8802
    }))
    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "player", "nauvis", "stone-furnace"))
  end)
end)
