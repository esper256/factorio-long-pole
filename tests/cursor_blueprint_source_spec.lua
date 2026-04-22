local cursor_blueprint_source = require("util.cursor_blueprint_source")

describe("cursor_blueprint_source", function()
  local function make_stack(spec)
    local stack = {
      valid_for_read = spec.valid_for_read ~= false,
      is_blueprint_book = spec.is_blueprint_book == true,
      is_blueprint = spec.is_blueprint == true,
      label = spec.label,
      active_index = spec.active_index,
      inventory = spec.inventory
    }

    function stack.get_inventory(_inventory_id)
      return stack.inventory
    end

    function stack.get_blueprint_entity_count()
      return spec.entity_count or 0
    end

    function stack.get_blueprint_entities()
      return spec.entities or {}
    end

    function stack.export_stack()
      return spec.export_string
    end

    return stack
  end

  local function make_record(spec)
    local record = {
      valid = spec.valid ~= false,
      type = spec.type,
      label = spec.label
    }

    function record.get_active_index(_player)
      return spec.active_index
    end

    function record.get_selected_record(_player)
      return spec.selected_record
    end

    function record.export_record()
      return spec.export_string
    end

    function record.get_blueprint_entity_count()
      return spec.entity_count or 0
    end

    function record.get_blueprint_entities()
      return spec.entities or {}
    end

    function record.is_blueprint_setup()
      return spec.is_setup == true
    end

    return record
  end

  it("finds a blueprint book in cursor_record before cursor_stack", function()
    local player = {
      cursor_record = make_record({
        type = "blueprint-book",
        label = "Record Book"
      }),
      cursor_stack = make_stack({
        is_blueprint_book = true,
        label = "Stack Book"
      })
    }

    local resolved = cursor_blueprint_source.find_cursor_blueprint_book(player)

    assert.are.equal("cursor_record", resolved.carrier)
    assert.are.equal("Record Book", resolved.source.label)
  end)

  it("resolves the selected blueprint from a cursor_record blueprint book", function()
    local selected_record = make_record({
      type = "blueprint",
      is_setup = true,
      export_string = "record-blueprint"
    })
    local player = {
      cursor_record = make_record({
        type = "blueprint-book",
        label = "Record Book",
        active_index = 3,
        selected_record = selected_record
      })
    }

    local resolved, error_message = cursor_blueprint_source.resolve_selected_blueprint(player)

    assert.is_nil(error_message)
    assert.are.equal("cursor_record", resolved.carrier)
    assert.are.equal(selected_record, resolved.source)
    assert.are.equal("Record Book", resolved.source_book_label)
    assert.are.equal(3, resolved.source_book_active_index)
  end)

  it("resolves the selected blueprint from a cursor_stack blueprint book", function()
    local blueprint_stack = make_stack({
      is_blueprint = true,
      entity_count = 2,
      export_string = "stack-blueprint"
    })
    local player = {
      cursor_stack = make_stack({
        is_blueprint_book = true,
        label = "Stack Book",
        active_index = 2,
        inventory = {
          [2] = blueprint_stack
        }
      })
    }

    local resolved, error_message = cursor_blueprint_source.resolve_selected_blueprint(player)

    assert.is_nil(error_message)
    assert.are.equal("cursor_stack", resolved.carrier)
    assert.are.equal(blueprint_stack, resolved.source)
    assert.are.equal("Stack Book", resolved.source_book_label)
    assert.are.equal(2, resolved.source_book_active_index)
  end)

  it("falls back to blueprint_to_setup when requested", function()
    local player = {
      cursor_stack = {
        valid_for_read = false
      },
      blueprint_to_setup = make_stack({
        is_blueprint = true,
        entity_count = 1,
        export_string = "setup-blueprint"
      })
    }

    local resolved, error_message = cursor_blueprint_source.resolve_selected_blueprint(player)

    assert.is_nil(error_message)
    assert.are.equal("blueprint_to_setup", resolved.carrier)
    assert.are.equal("setup-blueprint", resolved.source.export_stack())
  end)

  it("reports missing selected blueprints in books consistently", function()
    local player = {
      cursor_record = make_record({
        type = "blueprint-book",
        label = "Broken Book",
        active_index = 1,
        selected_record = nil
      })
    }

    local resolved, error_message = cursor_blueprint_source.resolve_selected_blueprint(player)

    assert.is_nil(resolved)
    assert.are.equal("The held blueprint book does not have an active blueprint selected.", error_message)
  end)
end)
