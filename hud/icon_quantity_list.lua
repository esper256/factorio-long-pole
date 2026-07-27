-- Compact horizontal item icon and quantity pairs for unfinished requirements.
local M = {}

local ICON_SIZE = 8
local MAX_ENTRIES = 8

function M.add(parent, name, width)
  local list = parent.add({
    type = "flow",
    name = name,
    direction = "horizontal"
  })
  list.style.minimal_width = width
  list.style.maximal_width = width
  list.style.margin = 0
  list.style.padding = 0
  list.style.horizontal_spacing = 0
  return list
end

local function compact_count(count)
  if count < 1000 then
    return tostring(math.ceil(count))
  end
  if count < 10000 then
    return ("%.1fk"):format(count / 1000)
  end
  if count < 1000000 then
    return ("%dk"):format(math.floor(count / 1000))
  end
  if count < 10000000 then
    return ("%.1fM"):format(count / 1000000)
  end
  if count < 1000000000 then
    return ("%dM"):format(math.floor(count / 1000000))
  end
  if count < 10000000000 then
    return ("%.1fB"):format(count / 1000000000)
  end
  return ("%dB"):format(math.floor(count / 1000000000))
end

local function add_item(list, index, entry)
  local display_count = compact_count(entry.count)
  local pair = list.add({
    type = "flow",
    name = "entry_" .. index,
    direction = "horizontal",
    tooltip = entry.item_name .. ": " .. display_count
  })
  pair.style.margin = 0
  pair.style.padding = 0
  pair.style.horizontal_spacing = 0
  local icon = pair.add({
    type = "sprite",
    name = "item_icon",
    sprite = "item/" .. entry.item_name
  })
  icon.style.width = ICON_SIZE
  icon.style.height = ICON_SIZE
  local quantity = pair.add({
    type = "label",
    name = "quantity",
    caption = tostring(display_count)
  })
  quantity.style.font = "default-small"
end

function M.refresh(list, entries)
  list.clear()
  if not entries or #entries == 0 then
    list.visible = false
    return
  end

  for index = 1, math.min(#entries, MAX_ENTRIES) do
    add_item(list, index, entries[index])
  end
  list.visible = true
end

return M
