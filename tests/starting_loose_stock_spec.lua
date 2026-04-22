local progress_tracker_store = require("progress_tracker_store")
local starting_loose_stock = require("util.starting_loose_stock")

describe("starting_loose_stock", function()
  it("grants the configured starter items exactly once", function()
    local state = {}
    progress_tracker_store.init(state)

    local player = {
      valid = true,
      force = {
        name = "player"
      },
      surface = {
        name = "nauvis"
      }
    }

    assert.is_true(starting_loose_stock.grant_once(state, player))
    assert.is_false(starting_loose_stock.grant_once(state, player))

    assert.are.equal(10, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "firearm-magazine"))
    assert.are.equal(8, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-plate"))
    assert.are.equal(1, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "wood"))
    assert.are.equal(1, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "stone-furnace"))
    assert.are.equal(1, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "burner-mining-drill"))
    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "copper-plate"))
  end)

  it("does nothing for invalid players", function()
    local state = {}
    progress_tracker_store.init(state)

    assert.is_false(starting_loose_stock.grant_once(state, nil))
    assert.is_false(starting_loose_stock.grant_once(state, {
      valid = false
    }))
    assert.is_false(starting_loose_stock.was_granted(state))
  end)
end)
