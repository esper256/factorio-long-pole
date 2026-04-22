local item_progress_icon = require("gui.item_progress_icon")

describe("item_progress_icon", function()
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
      tags = spec.tags,
      visible = spec.visible ~= false,
      enabled = spec.enabled ~= false,
      ignored_by_interaction = spec.ignored_by_interaction,
      quality = spec.quality,
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

  it("supports interactive icons and caller-supplied tags", function()
    local parent = make_element({
      type = "flow",
      direction = "vertical"
    })

    local root = item_progress_icon.add(parent, {
      kind = "item",
      name = "transport-belt",
      progress = 0.5
    }, {
      button_name = "long_pole_requirement_icon",
      build_tags = function(entry)
        return {
          requirement_name = entry.name
        }
      end
    })

    local button = root[item_progress_icon.icon_name]

    assert.are.equal("long_pole_requirement_icon", button.name)
    assert.same({
      requirement_name = "transport-belt"
    }, button.tags)
    assert.is_nil(button.ignored_by_interaction)
  end)

  it("updates icon state, clamps progress, and can hide the bar entirely", function()
    local parent = make_element({
      type = "flow",
      direction = "vertical"
    })

    local root = item_progress_icon.add(parent, {
      name = "coal",
      progress = 0
    })

    item_progress_icon.set_data(root, {
      kind = "item",
      name = "processing-unit",
      count = 3,
      quality = "normal",
      progress = 4,
      progress_color = {r = 1, g = 1, b = 1},
      desaturate = true,
      tooltip = "Ready soon"
    })

    local button = root[item_progress_icon.icon_name]
    local progress = root[item_progress_icon.progress_name]

    assert.are.equal("item/processing-unit", button.sprite)
    assert.are.equal(3, button.number)
    assert.are.equal("normal", button.quality)
    assert.are.equal("Ready soon", button.tooltip)
    assert.is_true(button.style.draw_grayscale_picture)
    assert.are.equal(1, progress.value)
    assert.are.same({r = 1, g = 1, b = 1}, progress.style.color)
    assert.is_true(progress.visible)

    item_progress_icon.set_data(root, {
      kind = "item",
      name = "processing-unit",
      count = 3
    })

    assert.is_false(progress.visible)
  end)
end)
