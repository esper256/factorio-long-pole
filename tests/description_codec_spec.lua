local codec = require("util.description_codec")

describe("description_codec", function()
  it("exports plan descriptions", function()
    local description = assert(codec.export_to_description({
      format = "long-pole-plan",
      plan_id = "plan-42",
      plan_name = "Any% Practice Plan",
      visibility = "references-only",
      default_surface = "nauvis"
    }))

    assert.are.equal(codec.example_plan_description, description)
  end)

  it("exports split descriptions", function()
    local description = assert(codec.export_to_description({
      format = "long-pole-split",
      split_name = "Starter Burners",
      surface = "nauvis",
      items = {
        {name = "transport-belt", count = 200},
        {name = "iron-chest", count = 3}
      },
      technologies = {
        {name = "automation"},
        {name = "logistics"}
      },
      notes = "Feed gears before circuits."
    }))

    assert.are.equal(codec.example_split_description, description)
  end)

  it("exports blueprint link descriptions", function()
    local description = assert(codec.export_to_description({
      format = "long-pole-blueprint-link",
      link_mode = "reference",
      library_root = "player-blueprints",
      inside_books = {"Any% Openers", "Burner Starts", "Safe Variants"},
      blueprint_name = "Starter burner pair",
      blueprint_slot = 2,
      blueprint_fingerprint = "burner-mining-drill:2;stone-furnace:2",
      entity_summary = {
        {name = "burner-mining-drill", count = 2},
        {name = "stone-furnace", count = 2}
      }
    }))

    assert.are.equal(codec.example_blueprint_link_description, description)
  end)

  it("imports plan descriptions", function()
    local decoded = assert(codec.import_from_description(codec.example_plan_description))

    assert.same({
      format = "long-pole-plan",
      version = 1,
      plan_id = "plan-42",
      plan_name = "Any% Practice Plan",
      visibility = "references-only",
      default_surface = "nauvis"
    }, decoded)
  end)

  it("imports split descriptions", function()
    local decoded = assert(codec.import_from_description(codec.example_split_description))

    assert.same({
      format = "long-pole-split",
      version = 1,
      split_name = "Starter Burners",
      name = "Starter Burners",
      surface = "nauvis",
      items = {
        {name = "transport-belt", count = 200},
        {name = "iron-chest", count = 3}
      },
      technologies = {
        {name = "automation"},
        {name = "logistics"}
      },
      notes = "Feed gears before circuits."
    }, decoded)
  end)

  it("imports blueprint link descriptions", function()
    local decoded = assert(codec.import_from_description(codec.example_blueprint_link_description))

    assert.same({
      format = "long-pole-blueprint-link",
      version = 1,
      link_mode = "reference",
      library_root = "player-blueprints",
      inside_books = {"Any% Openers", "Burner Starts", "Safe Variants"},
      blueprint_name = "Starter burner pair",
      blueprint_slot = 2,
      blueprint_fingerprint = "burner-mining-drill:2;stone-furnace:2",
      name = "Starter burner pair",
      source_book_label = "Any% Openers",
      source_book_active_index = 2,
      entity_summary = {
        {name = "burner-mining-drill", count = 2},
        {name = "stone-furnace", count = 2}
      },
      entity_count = 4
    }, decoded)
  end)

  it("imports root library blueprint link descriptions", function()
    local decoded = assert(codec.import_from_description(codec.example_blueprint_link_root_description))

    assert.same({
      format = "long-pole-blueprint-link",
      version = 1,
      link_mode = "reference",
      library_root = "player-blueprints",
      inside_books = {},
      blueprint_name = "Direct Library Blueprint",
      blueprint_slot = 7,
      blueprint_fingerprint = "transport-belt:12;inserter:4",
      name = "Direct Library Blueprint",
      source_book_label = nil,
      source_book_active_index = 7,
      entity_summary = {
        {name = "transport-belt", count = 12},
        {name = "inserter", count = 4}
      },
      entity_count = 16
    }, decoded)
  end)
end)
