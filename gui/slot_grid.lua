local M = {}

local function build_button_name(base_name, index)
  return ("%s_%d"):format(base_name, index)
end

local function default_sprite(entry)
  if not entry then
    return nil
  end

  if entry.sprite then
    return entry.sprite
  end

  if entry.kind and entry.name then
    return ("%s/%s"):format(entry.kind, entry.name)
  end

  if entry.name and entry.name ~= "" then
    return "item/" .. entry.name
  end

  return nil
end

local function default_tooltip(entry)
  if not entry then
    return nil
  end

  if entry.tooltip then
    return entry.tooltip
  end

  local item_name = entry.name or "Unnamed"
  local count = entry.count and tostring(entry.count) or "0"
  return {"", item_name, " x", count}
end

local function resolve_option_value(option, entry, index)
  if type(option) == "function" then
    return option(entry, index)
  end

  return option
end

function M.add(parent, entries, options)
  options = options or {}
  entries = entries or {}

  local scroll = parent.add({
    type = "scroll-pane",
    vertical_scroll_policy = options.vertical_scroll_policy or "auto",
    horizontal_scroll_policy = options.horizontal_scroll_policy or "never"
  })
  scroll.style.horizontally_stretchable = options.horizontally_stretchable ~= false
  scroll.style.vertically_stretchable = options.vertically_stretchable ~= false
  if options.minimal_height then
    scroll.style.minimal_height = options.minimal_height
  end
  if options.maximal_height then
    scroll.style.maximal_height = options.maximal_height
  end
  if options.top_margin then
    scroll.style.top_margin = options.top_margin
  end

  local grid = scroll.add({
    type = "table",
    column_count = options.column_count or 10
  })
  grid.style.horizontal_spacing = options.horizontal_spacing or 4
  grid.style.vertical_spacing = options.vertical_spacing or 4

  local visible_entry_count = math.max(#entries, options.minimum_entry_count or #entries)
  if visible_entry_count == 0 then
    visible_entry_count = 1
  end

  for index = 1, visible_entry_count do
    local entry = entries[index]
    local button_spec = {
      type = "sprite-button",
      sprite = entry and default_sprite(entry) or options.empty_sprite,
      tooltip = entry and default_tooltip(entry) or options.empty_tooltip
    }
    if options.button_name then
      button_spec.name = build_button_name(options.button_name, index)
    end

    local tags = options.build_tags and options.build_tags(entry, index) or nil
    if options.button_name then
      tags = tags or {}
      tags.slot_grid_action = options.button_name
      tags.slot_grid_index = index
    end
    if tags then
      button_spec.tags = tags
    end

    local button = grid.add(button_spec)
    button.style = options.button_style or "slot_button"
    button.style.width = options.slot_size or 40
    button.style.height = options.slot_size or 40
    if options.button_auto_toggle ~= nil then
      button.auto_toggle = resolve_option_value(options.button_auto_toggle, entry, index)
    end
    if options.button_toggled ~= nil then
      button.toggled = resolve_option_value(options.button_toggled, entry, index)
    end
    if entry and entry.count then
      button.number = entry.count
    end
    if options.button_name then
      if options.button_enabled ~= nil then
        button.enabled = resolve_option_value(options.button_enabled, entry, index)
      end
    else
      button.ignored_by_interaction = true
    end
  end

  return scroll, grid
end

function M.matches_action(element, action_name)
  if not (element and element.valid and action_name) then
    return false
  end

  if element.tags and element.tags.slot_grid_action == action_name then
    return true
  end

  return element.name == action_name or element.name:match("^" .. action_name .. "_%d+$") ~= nil
end

return M
