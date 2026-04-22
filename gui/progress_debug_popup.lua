local slot_grid = require("gui.slot_grid")

local M = {}

-- This popup is intentionally simple: it exposes the tracker ledger directly so
-- reviewers can spot accounting drift without interpreting the higher-level UI.

local GRID_COLUMNS = 8
local GRID_SLOT_SIZE = 36
local GRID_MAX_HEIGHT = 180

local function sort_entries(entries)
  table.sort(entries, function(a, b)
    if a.count == b.count then
      return a.name < b.name
    end
    return a.count > b.count
  end)
end

local function build_grid_entries(snapshot_entries, field_name, tooltip_title)
  local entries = {}
  for _, entry in ipairs(snapshot_entries or {}) do
    local count = entry[field_name] or 0
    if count > 0 then
      entries[#entries + 1] = {
        name = entry.item_name,
        count = count,
        tooltip = {"", tooltip_title, "\n", "[item=", entry.item_name, "] ", entry.item_name, " x", count}
      }
    end
  end
  sort_entries(entries)
  return entries
end

local function add_section(parent, title, entries)
  local section = parent.add({
    type = "flow",
    direction = "vertical"
  })
  section.style.horizontally_stretchable = true

  local heading = section.add({
    type = "label",
    caption = title
  })
  heading.style = "caption_label"

  slot_grid.add(section, entries, {
    column_count = GRID_COLUMNS,
    slot_size = GRID_SLOT_SIZE,
    maximal_height = GRID_MAX_HEIGHT,
    vertically_stretchable = false,
    minimum_entry_count = math.max(#entries, GRID_COLUMNS),
    empty_sprite = "utility/empty_module_slot",
    empty_tooltip = title
  })
end

function M.add(parent, snapshot)
  local frame = parent.add({
    type = "frame",
    direction = "vertical"
  })
  frame.style.top_margin = 6
  frame.style.horizontally_stretchable = true

  local content = frame.add({
    type = "flow",
    direction = "vertical"
  })
  content.style.horizontally_stretchable = true
  content.style.left_padding = 4
  content.style.right_padding = 4
  content.style.top_padding = 4
  content.style.bottom_padding = 4

  local placed_entries = build_grid_entries(snapshot.entries, "placed_count", "Placed")
  local loose_entries = build_grid_entries(snapshot.entries, "loose_stock", "Loose")

  add_section(content, "Placed", placed_entries)
  add_section(content, "Loose", loose_entries)

  if snapshot.uncertainty and snapshot.uncertainty.since_tick ~= nil then
    -- Surface uncertainty is a first-class signal. Showing it here makes it
    -- clear when the tracker is guessing instead of silently pretending to know.
    local warning = content.add({
      type = "label",
      caption = "Estimate may be out of sync"
    })
    warning.style.top_margin = 4
    warning.style.font_color = {1, 0.7, 0.2}
    if snapshot.uncertainty.reason then
      warning.tooltip = snapshot.uncertainty.reason
    end
  end

  return frame
end

return M
