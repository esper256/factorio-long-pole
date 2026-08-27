-- Compact horizontal item icon and quantity pairs for unfinished requirements.
-- Updates existing children in place so the 1-second pulse does not rebuild
-- the row when the set of icons did not change.
--
-- Caption is ETA when the factory is producing the item, otherwise remaining
-- count. Sort order is the caller's responsibility (longest pole first).
local eta = require("progress_analysis.eta")

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

local function caption_for(entry)
  if (entry.produced_per_minute or 0) > 0 and entry.eta_ticks then
    return eta.format_ticks(entry.eta_ticks)
  end
  return compact_count(entry.count)
end

local function tooltip_for(entry, caption)
  local count = compact_count(entry.count)
  if caption == count then
    return entry.item_name .. ": " .. count
  end
  return entry.item_name .. ": " .. caption .. " · " .. count
end

local function add_item(list, index, entry)
  local caption = caption_for(entry)
  local pair = list.add({
    type = "flow",
    name = "entry_" .. index,
    direction = "horizontal",
    tooltip = tooltip_for(entry, caption)
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
  icon.style.stretch_image_to_widget_size = true
  local quantity = pair.add({
    type = "label",
    name = "quantity",
    caption = caption
  })
  quantity.style.font = "default-small"
  quantity.style.padding = 0
end

local function update_item(pair, entry)
  local caption = caption_for(entry)
  pair.tooltip = tooltip_for(entry, caption)
  pair.item_icon.sprite = "item/" .. entry.item_name
  pair.quantity.caption = caption
end

function M.refresh(list, entries)
  entries = entries or {}
  local shown = math.min(#entries, MAX_ENTRIES)
  if shown == 0 then
    list.clear()
    list.visible = false
    return
  end

  local index = 1
  while list["entry_" .. index] and index <= shown do
    update_item(list["entry_" .. index], entries[index])
    index = index + 1
  end
  while list["entry_" .. index] do
    list["entry_" .. index].destroy()
    index = index + 1
  end
  for add_index = 1, shown do
    if not list["entry_" .. add_index] then
      add_item(list, add_index, entries[add_index])
    end
  end
  list.visible = true
end

return M
