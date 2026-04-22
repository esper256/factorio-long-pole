local plan_storage = require("plan_storage")
local item_progress_icon = require("gui.item_progress_icon")
local plan_editor = require("gui.plan_editor")
local progress_debug_popup = require("gui.progress_debug_popup")
local tracker = require("split_tracker")

local M = {}

M.root_name = "long_pole_split_viewer"
M.open_editor_button_name = "long_pole_open_plan_editor"
M.advance_split_button_name = "long_pole_advance_split"
M.title_toggle_button_name = "long_pole_split_viewer_title_toggle"

local ICON_LIMIT_SETTING = "long-pole-split-viewer-icon-limit"
local DEFAULT_ICON_LIMIT = 5
local ICON_SLOT_SIZE = 28
local ICON_PROGRESS_BAR_WIDTH = 3
local GROUP_SPACING = 10
local ALERT_PROGRESS_COLOR = {r = 0.85, g = 0.25, b = 0.25}

local function ensure_registry(state)
  state.split_viewer = state.split_viewer or {}
  state.split_viewer.debug_popup_visible_by_player = state.split_viewer.debug_popup_visible_by_player or {}
  return state.split_viewer
end

local function is_debug_popup_visible(state, player_index)
  return ensure_registry(state).debug_popup_visible_by_player[player_index] == true
end

local function set_debug_popup_visible(state, player_index, visible)
  ensure_registry(state).debug_popup_visible_by_player[player_index] = visible and true or nil
end

local function format_elapsed_ticks(elapsed_ticks)
  local total_seconds = math.floor((elapsed_ticks or 0) / 60)
  local minutes = math.floor(total_seconds / 60)
  local seconds = total_seconds % 60
  local hours = math.floor(minutes / 60)
  minutes = minutes % 60

  if hours > 0 then
    return ("%d:%02d:%02d"):format(hours, minutes, seconds)
  end

  return ("%02d:%02d"):format(minutes, seconds)
end

local function destroy_children(element)
  for index = #element.children, 1, -1 do
    local child = element.children[index]
    if child then
      child.destroy()
    end
  end
end

local function icon_limit()
  local settings_root = settings and settings.global
  local setting = settings_root and settings_root[ICON_LIMIT_SETTING]
  local configured_value = setting and tonumber(setting.value) or DEFAULT_ICON_LIMIT
  return math.max(1, math.floor(configured_value or DEFAULT_ICON_LIMIT))
end

local function sort_icon_entries(entries, sort_mode)
  local sorted = {}
  for index, entry in ipairs(entries or {}) do
    sorted[index] = entry
  end

  table.sort(sorted, function(a, b)
    if sort_mode == "remaining" then
      local count_a = a.count or 0
      local count_b = b.count or 0
      if count_a ~= count_b then
        return count_a > count_b
      end
    else
      local progress_a = a.progress or 1
      local progress_b = b.progress or 1
      if progress_a ~= progress_b then
        return progress_a < progress_b
      end
    end

    local count_a = a.count or 0
    local count_b = b.count or 0
    if count_a ~= count_b then
      return count_a > count_b
    end

    if (a.kind or "item") == (b.kind or "item") then
      return (a.name or "") < (b.name or "")
    end

    return (a.kind or "item") < (b.kind or "item")
  end)

  return sorted
end

local function group_tooltip_title(group_kind)
  if group_kind == "carry-over-stock" then
    return "Carry-over stock still missing"
  end
  if group_kind == "placement-progress" then
    return "Still to place for this split"
  end
  if group_kind == "research-production" then
    return "Still to produce for this split's research"
  end
  if group_kind == "next-split-readiness" then
    return "Still missing before the next split is stock-ready"
  end

  return "Split progress"
end

local function build_icon_tooltip(entry, group_kind)
  local tooltip = {"", group_tooltip_title(group_kind), "\n", "[", entry.kind or "item", "=", entry.name, "] ", entry.name}

  if entry.count ~= nil then
    tooltip[#tooltip + 1] = "\nMissing: "
    tooltip[#tooltip + 1] = tostring(entry.count)
  end

  if entry.fulfilled_count ~= nil and entry.required_count ~= nil then
    tooltip[#tooltip + 1] = "\nProgress: "
    tooltip[#tooltip + 1] = tostring(entry.fulfilled_count)
    tooltip[#tooltip + 1] = "/"
    tooltip[#tooltip + 1] = tostring(entry.required_count)
  end

  return tooltip
end

local function add_group_overflow(parent, hidden_count, tone)
  if hidden_count <= 0 then
    return
  end

  local overflow = parent.add({
    type = "label",
    caption = ("... +%d"):format(hidden_count)
  })
  overflow.style.left_margin = 2
  overflow.style.right_margin = 2
  if tone == "alert" then
    overflow.style.font_color = ALERT_PROGRESS_COLOR
  else
    overflow.style.font_color = {0.8, 0.8, 0.8}
  end
end

local function add_icon_group(parent, group)
  if not group or not group.entries or #group.entries == 0 then
    return false
  end

  local sorted_entries = sort_icon_entries(group.entries, group.sort_mode)
  local limit = icon_limit()
  local visible_count = math.min(limit, #sorted_entries)
  local group_flow = parent.add({
    type = "flow",
    direction = "horizontal"
  })
  group_flow.style.horizontal_spacing = 4

  for index = 1, visible_count do
    local entry = sorted_entries[index]
    item_progress_icon.add(group_flow, {
      kind = entry.kind or "item",
      name = entry.name,
      count = entry.count,
      progress = entry.progress,
      progress_color = group.tone == "alert" and ALERT_PROGRESS_COLOR or nil,
      tooltip = build_icon_tooltip(entry, group.kind)
    }, {
      slot_size = ICON_SLOT_SIZE,
      progress_bar_width = ICON_PROGRESS_BAR_WIDTH
    })
  end

  add_group_overflow(group_flow, #sorted_entries - visible_count, group.tone)
  return true
end

local function add_icon_groups(parent, groups)
  local rendered_groups = {}
  for _, group in ipairs(groups or {}) do
    if group and group.entries and #group.entries > 0 then
      rendered_groups[#rendered_groups + 1] = group
    end
  end

  for index, group in ipairs(rendered_groups) do
    add_icon_group(parent, group)
    if index < #rendered_groups then
      local spacer = parent.add({
        type = "empty-widget"
      })
      spacer.style.width = GROUP_SPACING
      spacer.style.height = 1
    end
  end
end

local function add_split_row(parent, status)
  if not status then
    return
  end

  local row = parent.add({
    type = "flow",
    direction = "horizontal"
  })
  row.style.horizontally_stretchable = true
  row.style.horizontal_spacing = 8

  local name_label = row.add({
    type = "label",
    caption = status.name
  })
  name_label.style.minimal_width = 150
  if status.is_current then
    name_label.style = "bold_label"
  end

  if status.is_current then
    local stopwatch_button = row.add({
      type = "button",
      name = M.advance_split_button_name,
      caption = format_elapsed_ticks(status.elapsed_ticks or 0)
    })
    stopwatch_button.style.minimal_width = 58
    stopwatch_button.style.left_margin = 4
    stopwatch_button.tooltip = status.is_ready_to_complete
      and "Stop the stopwatch and complete this split."
      or "Stop the stopwatch and advance to the next split."
    if status.is_ready_to_complete then
      stopwatch_button.style.font_color = {0.3, 0.8, 0.3}
    end
  elseif status.completed_elapsed_ticks ~= nil then
    local elapsed_label = row.add({
      type = "label",
      caption = format_elapsed_ticks(status.completed_elapsed_ticks)
    })
    elapsed_label.style.minimal_width = 45
    elapsed_label.style.font_color = {0.75, 0.75, 0.75}
  else
    local spacer = row.add({
      type = "empty-widget"
    })
    spacer.style.minimal_width = 45
    spacer.style.width = 45
    spacer.style.height = 1
  end

  local requirements_flow = row.add({
    type = "flow",
    direction = "horizontal"
  })
  requirements_flow.style.horizontally_stretchable = true
  requirements_flow.style.horizontal_spacing = 4
  add_icon_groups(requirements_flow, status.icon_groups)
end

function M.refresh(player, state)
  local frame = player.gui.left[M.root_name]
  if not frame then
    frame = player.gui.left.add({
      type = "frame",
      name = M.root_name,
      direction = "vertical"
    })
    frame.style.horizontally_stretchable = true
  end

  destroy_children(frame)

  local header = frame.add({
    type = "flow",
    direction = "horizontal"
  })
  header.style.horizontally_stretchable = true

  local entry_button = plan_storage.entry_button_spec(player, state)
  local open_editor = header.add({
    type = "button",
    name = M.open_editor_button_name,
    caption = entry_button.caption
  })
  open_editor.tooltip = entry_button.tooltip
  if entry_button.is_compact then
    open_editor.style.width = 28
    open_editor.style.height = 28
    open_editor.style.left_padding = 0
    open_editor.style.right_padding = 0
    open_editor.style.top_padding = 0
    open_editor.style.bottom_padding = 0
  end

  local title = header.add({
    type = "button",
    name = M.title_toggle_button_name,
    caption = is_debug_popup_visible(state, player.index) and "Splits -" or "Splits +"
  })
  title.style.left_padding = 0
  title.style.right_padding = 0
  title.style.top_padding = 0
  title.style.bottom_padding = 0
  title.style.left_margin = 6
  title.style.font_color = {1, 1, 1}
  title.tooltip = "Click to toggle placed and loose item totals."

  local body = frame.add({
    type = "flow",
    direction = "vertical"
  })
  body.style.top_margin = 6

  local current_tick = game and game.tick or 0
  tracker.ensure_current_split_started(state, current_tick)
  local force_name = player.force and player.force.name or "player"
  local status = tracker.get_split_status(state, force_name)
  if status.current then
    status.current.elapsed_ticks = tracker.current_split_elapsed_ticks(state, current_tick)
  end

  if is_debug_popup_visible(state, player.index) then
    progress_debug_popup.add(frame, tracker.get_current_split_progress_snapshot(state, force_name))
  end

  add_split_row(body, status.previous)
  add_split_row(body, status.current)
  for _, split_status in ipairs(status.upcoming) do
    add_split_row(body, split_status)
  end
end

function M.handle_click(player, state, element, event)
  if element.name == M.open_editor_button_name then
    if plan_storage.importable_plan_from_player(player) then
      local ok, error_message = plan_storage.import_plan_from_cursor(player, state)
      if not ok then
        player.print(error_message)
        return false
      end

      return true
    end

    if plan_storage.has_active_plan(state) then
      plan_editor.open(player, state)
      return true
    end

    local ok = plan_storage.create_new_plan(state)
    local error_message = nil

    if not ok then
      player.print(error_message)
      return false
    end

    plan_editor.open(player, state)
    return true
  end

  if element.name == M.title_toggle_button_name then
    set_debug_popup_visible(state, player.index, not is_debug_popup_visible(state, player.index))
    return true
  end

  if element.name == M.advance_split_button_name then
    tracker.advance_split(state, event and event.tick or nil)
    return true
  end

  return false
end

return M
