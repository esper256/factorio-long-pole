-- A compact, reusable three-state progress bar. Callers supply domain-specific
-- meanings for done, pending, and not started through its tooltip.
local M = {}

local DONE_NAME = "done"
local PENDING_NAME = "pending"
local NOT_STARTED_NAME = "not_started"

local COLORS = {
  done = { r = 0.36, g = 0.70, b = 0.27 },
  pending = { r = 0.94, g = 0.64, b = 0.18 },
  not_started = { r = 0.36, g = 0.36, b = 0.36 }
}

local function add_segment(parent, name, color)
  local segment = parent.add({
    type = "progressbar",
    name = name,
    value = 1
  })
  segment.style.bar_width = 6
  segment.style.margin = 0
  segment.style.padding = 0
  segment.style.color = color
  return segment
end

local function clamp(value, minimum, maximum)
  return math.max(minimum, math.min(value, maximum))
end

local function segment_width(total_width, amount, total)
  if amount == 0 then
    return 0
  end
  return math.max(1, math.floor(total_width * amount / total))
end

function M.add(parent, name, width)
  local bar = parent.add({
    type = "flow",
    name = name,
    direction = "horizontal"
  })
  bar.style.minimal_width = width
  bar.style.maximal_width = width
  bar.style.horizontal_spacing = 0
  add_segment(bar, DONE_NAME, COLORS.done)
  add_segment(bar, PENDING_NAME, COLORS.pending)
  add_segment(bar, NOT_STARTED_NAME, COLORS.not_started)
  return bar
end

function M.refresh(bar, progress)
  assert(type(progress.total) == "number" and progress.total >= 0, "progress total must be non-negative")
  assert(type(progress.done) == "number" and progress.done >= 0, "progress done must be non-negative")
  assert(type(progress.pending) == "number" and progress.pending >= 0, "progress pending must be non-negative")

  if progress.total == 0 then
    bar.visible = false
    return
  end

  local done = clamp(progress.done, 0, progress.total)
  local pending = clamp(progress.pending, 0, progress.total - done)
  local not_started = progress.total - done - pending
  local width = bar.style.minimal_width

  local done_segment = bar[DONE_NAME]
  local pending_segment = bar[PENDING_NAME]
  local not_started_segment = bar[NOT_STARTED_NAME]
  local done_width = segment_width(width, done, progress.total)
  local pending_width = segment_width(width, pending, progress.total)
  local not_started_width = width - done_width - pending_width

  done_segment.visible = done_width > 0
  done_segment.style.width = done_width
  pending_segment.visible = pending_width > 0
  pending_segment.style.width = pending_width
  not_started_segment.visible = not_started_width > 0
  not_started_segment.style.width = not_started_width
  bar.tooltip = progress.tooltip
  bar.visible = true
end

return M
