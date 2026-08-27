local progress_tracker_store = require("progress_tracker_store")

describe("progress_tracker_store", function()
  it("initializes runtime progress storage separately from plan state", function()
    local state = {}

    local root = progress_tracker_store.init(state)

    assert.is_table(root)
    assert.are.equal(3, root.storage_version)
    assert.is_table(root.forces)
    assert.is_table(root.placed_entity_index)
  end)

  it("stores loose stock by surface and item prototype name", function()
    local state = {}
    progress_tracker_store.init(state)

    assert.is_true(progress_tracker_store.set_loose_stock(state, "player", "nauvis", "transport-belt", 12.9))
    assert.is_true(progress_tracker_store.adjust_loose_stock(state, "player", "nauvis", "transport-belt", -4))
    assert.is_true(progress_tracker_store.adjust_loose_stock(state, "player", "nauvis", "iron-chest", 3))
    assert.is_true(progress_tracker_store.adjust_loose_stock(state, "enemy", "gleba", "transport-belt", 2))
    assert.is_true(progress_tracker_store.adjust_loose_stock(state, "player", "nauvis", "transport-belt", -999))

    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "transport-belt"))
    assert.are.equal(3, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-chest"))
    assert.are.equal(2, progress_tracker_store.get_loose_stock(state, "enemy", "gleba", "transport-belt"))
  end)

  it("tracks placed entities separately from loose stock and aggregates by item icon key", function()
    local state = {}
    progress_tracker_store.init(state)

    assert.is_true(progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 101,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "assembling-machine-1",
      entity_name = "assembling-machine-1",
      split_id = 7,
      placed_tick = 120
    }))
    assert.is_true(progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 102,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "assembling-machine-1",
      entity_name = "assembling-machine-1",
      split_id = 8,
      placed_tick = 150
    }))
    assert.is_true(progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 102,
      force_name = "enemy",
      surface_name = "gleba",
      item_name = "assembling-machine-2",
      entity_name = "assembling-machine-2",
      split_id = 8,
      placed_tick = 210
    }))

    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "player", "nauvis", "assembling-machine-1"))
    assert.are.equal(1, progress_tracker_store.get_placed_count(state, "enemy", "gleba", "assembling-machine-2"))
    assert.are.equal(0, progress_tracker_store.get_placed_count(state, "player", "nauvis", "assembling-machine-2"))

    assert.is_true(progress_tracker_store.remove_placed_entity(state, 101))
    assert.are.equal(0, progress_tracker_store.get_placed_count(state, "player", "nauvis", "assembling-machine-1"))
  end)

  it("syncs item production statistics into cumulative totals and loose-stock deltas", function()
    local state = {}
    progress_tracker_store.init(state)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-plate", 10)

    assert.is_true(progress_tracker_store.sync_item_production_statistics(state, "player", "nauvis", {
      input_counts = {
        ["iron-gear-wheel"] = 6
      },
      output_counts = {
        ["iron-plate"] = 4
      }
    }))

    local produced_total, consumed_total = progress_tracker_store.get_production_totals(state, "player", "nauvis", "iron-gear-wheel")
    assert.are.equal(6, produced_total)
    assert.are.equal(0, consumed_total)

    produced_total, consumed_total = progress_tracker_store.get_production_totals(state, "player", "nauvis", "iron-plate")
    assert.are.equal(0, produced_total)
    assert.are.equal(4, consumed_total)

    assert.are.equal(6, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-plate"))
    assert.are.equal(6, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-gear-wheel"))
  end)

  it("uses production exclusions to avoid double counting event-tracked outputs in statistics", function()
    local state = {}
    progress_tracker_store.init(state)
    progress_tracker_store.adjust_loose_stock(state, "player", "nauvis", "copper-cable", 1)
    progress_tracker_store.add_production_input_exclusion(state, "player", "nauvis", "copper-cable", 1)

    assert.is_true(progress_tracker_store.sync_item_production_statistics(state, "player", "nauvis", {
      input_counts = {
        ["copper-cable"] = 1
      },
      output_counts = {}
    }))

    local produced_total, consumed_total = progress_tracker_store.get_production_totals(state, "player", "nauvis", "copper-cable")
    assert.are.equal(0, produced_total)
    assert.are.equal(0, consumed_total)
    assert.are.equal(1, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "copper-cable"))
  end)

  it("builds a per-surface snapshot that the gui can render with item icons", function()
    local state = {}
    progress_tracker_store.init(state)

    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "transport-belt", 25)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "assembling-machine-1", 3)
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 11,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "assembling-machine-1",
      split_id = 4
    })
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 12,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "assembling-machine-1",
      split_id = 5
    })
    progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 13,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "burner-mining-drill",
      split_id = 4
    })
    progress_tracker_store.sync_item_production_statistics(state, "player", "nauvis", {
      input_counts = {
        ["transport-belt"] = 14
      },
      output_counts = {
        ["assembling-machine-1"] = 2
      }
    })
    progress_tracker_store.mark_surface_uncertain(state, "player", "nauvis", 900, "destroyed-container")

    local snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis", 4)

    assert.are.equal("player", snapshot.force_name)
    assert.are.equal("nauvis", snapshot.surface_name)
    assert.are.equal(900, snapshot.uncertainty.since_tick)
    assert.are.equal("destroyed-container", snapshot.uncertainty.reason)
    assert.are.equal(3, #snapshot.entries)

    assert.are.same({
      item_name = "assembling-machine-1",
      loose_stock = 1,
      placed_count = 2,
      current_split_claim = 1,
      produced_total = 0,
      consumed_total = 2,
      produced_rate = 0,
      consumed_rate = 0
    }, snapshot.entries[1])
    assert.are.same({
      item_name = "burner-mining-drill",
      loose_stock = 0,
      placed_count = 1,
      current_split_claim = 1,
      produced_total = 0,
      consumed_total = 0,
      produced_rate = 0,
      consumed_rate = 0
    }, snapshot.entries[2])
    assert.are.same({
      item_name = "transport-belt",
      loose_stock = 39,
      placed_count = 0,
      current_split_claim = 0,
      produced_total = 14,
      consumed_total = 0,
      produced_rate = 0,
      consumed_rate = 0
    }, snapshot.entries[3])
  end)

  it("tracks split claims incrementally when entities move or are removed", function()
    local state = {}
    progress_tracker_store.init(state)

    assert.is_true(progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 21,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "assembling-machine-1",
      split_id = 4
    }))

    local snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis", 4)
    assert.are.equal(1, snapshot.entries[1].current_split_claim)

    assert.is_true(progress_tracker_store.upsert_placed_entity(state, {
      unit_number = 21,
      force_name = "player",
      surface_name = "nauvis",
      item_name = "assembling-machine-1",
      split_id = 5
    }))

    local old_split_snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis", 4)
    local new_split_snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis", 5)
    assert.are.equal(0, old_split_snapshot.entries[1].current_split_claim)
    assert.are.equal(1, new_split_snapshot.entries[1].current_split_claim)

    assert.is_true(progress_tracker_store.remove_placed_entity(state, 21))
    local removed_snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis", 5)
    assert.are.equal(0, #removed_snapshot.entries)
  end)

  it("resets the ledger and marks underflow as uncertain without inventing production", function()
    local state = {}
    progress_tracker_store.init(state)
    progress_tracker_store.set_loose_stock(state, "player", "nauvis", "iron-plate", 2)
    progress_tracker_store.adjust_loose_stock(state, "player", "nauvis", "iron-plate", -9, {tick = 12})

    local snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis")
    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-plate"))
    assert.are.equal(12, snapshot.uncertainty.since_tick)
    assert.is_truthy(snapshot.uncertainty.reason)

    progress_tracker_store.sync_item_production_statistics(state, "player", "nauvis", {
      input_counts = {["iron-plate"] = 8},
      output_counts = {}
    })
    progress_tracker_store.sync_item_production_statistics(state, "player", "nauvis", {
      input_counts = {["iron-plate"] = 3},
      output_counts = {}
    })
    local produced_total = progress_tracker_store.get_production_totals(state, "player", "nauvis", "iron-plate")
    assert.are.equal(8, produced_total)
    snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis")
    assert.are.equal("production-statistics-reset", snapshot.uncertainty.reason)

    progress_tracker_store.reset(state)
    assert.are.equal(0, progress_tracker_store.get_loose_stock(state, "player", "nauvis", "iron-plate"))
    assert.are.equal(3, state.progress_tracker.storage_version)
  end)

  it("stores research progress separately from loose science packs", function()
    local state = {}
    progress_tracker_store.init(state)
    progress_tracker_store.set_research_progress(state, "player", "automation", 0.5)
    progress_tracker_store.set_pack_consumption_rate(state, "player", "automation-science-pack", 12)
    progress_tracker_store.set_lab_working_count(state, "player", 3)

    local snapshot = progress_tracker_store.get_surface_snapshot(state, "player", "nauvis")
    assert.are.equal(0.5, snapshot.research.by_name.automation.progress)
    assert.are.equal(12, snapshot.research.pack_consumption_per_minute["automation-science-pack"])
    assert.are.equal(3, snapshot.research.lab_working_count)
  end)
end)
