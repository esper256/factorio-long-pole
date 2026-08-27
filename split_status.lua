local build_requirements = require("build_requirements")

local M = {}

local function icon_group(entries, options)
  if not entries or #entries == 0 then
    return nil
  end

  return {
    entries = entries,
    tone = options and options.tone or "normal",
    sort_mode = options and options.sort_mode or "progress",
    kind = options and options.kind or "requirements"
  }
end

-- HUD model: one previous split as leftover-work yardstick, current remaining
-- work sorted by ETA (the long pole), next-split readiness from the next
-- split's own prints. Production/stock is the real signal; placement is bonus
-- (PRODUCT.md §1, §8, §11, §12).
function M.build(state, force_name, deps)
  deps = deps or {}
  local get_snapshot = deps.get_split_progress_snapshot
  local cached_root_requirements = deps.cached_root_requirements

  local statuses = {
    previous = nil,
    current = nil,
    upcoming = {}
  }

  local current_index = state.current_split_index
  local current_split = state.splits[current_index]
  local current_snapshot = nil
  local current_missing = {}
  local current_error_message = nil
  local current_reserved_pools = nil
  local current_placement_progress = {}
  local current_research_progress = {}
  local next_split_readiness = {}
  local previous_leftover = {}

  if current_split then
    current_snapshot = force_name and get_snapshot(state, current_index, force_name) or nil
    current_missing, current_error_message, current_reserved_pools = build_requirements.summarize_missing_requirements(
      current_split,
      current_snapshot,
      {
        root_requirements = cached_root_requirements(state, current_split, "all-requirements")
      }
    )
    current_placement_progress = build_requirements.summarize_direct_requirement_progress(current_split, current_snapshot, {
      root_requirements = cached_root_requirements(state, current_split, "placement-progress", {
        include_items = false,
        include_technologies = false,
        blueprint_satisfaction_mode = "placed_only"
      }),
      include_items = false,
      include_technologies = false,
      blueprint_satisfaction_mode = "placed_only"
    })
    current_research_progress = build_requirements.summarize_missing_requirements(current_split, current_snapshot, {
      root_requirements = cached_root_requirements(state, current_split, "research-progress", {
        include_blueprints = false,
        include_items = false
      }),
      include_blueprints = false,
      include_items = false
    })
  end

  local previous_split = state.splits[current_index - 1]
  if previous_split and force_name then
    local previous_snapshot
    if current_split and previous_split.surface == current_split.surface then
      previous_snapshot = current_snapshot or get_snapshot(state, current_index - 1, force_name)
    else
      previous_snapshot = get_snapshot(state, current_index - 1, force_name)
    end
    previous_leftover = build_requirements.summarize_missing_requirements(previous_split, previous_snapshot, {
      root_requirements = cached_root_requirements(state, previous_split, "previous-leftover")
    })
  elseif previous_split then
    previous_leftover = build_requirements.summarize_missing_requirements(previous_split, nil, {
      root_requirements = cached_root_requirements(state, previous_split, "previous-leftover")
    })
  end

  local next_split = state.splits[current_index + 1]
  if next_split then
    local next_snapshot = nil
    local next_initial_pools = nil

    if force_name and current_split and next_split.surface == current_split.surface then
      next_snapshot = current_snapshot
      next_initial_pools = current_reserved_pools
    elseif force_name then
      next_snapshot = get_snapshot(state, current_index + 1, force_name)
    end

    next_split_readiness = build_requirements.summarize_direct_requirement_progress(next_split, next_snapshot, {
      root_requirements = cached_root_requirements(state, next_split, "next-readiness", {
        include_technologies = false,
        blueprint_satisfaction_mode = "loose_only"
      }),
      include_technologies = false,
      blueprint_satisfaction_mode = "loose_only",
      initial_pools = next_initial_pools
    })
  end

  for index, split in ipairs(state.splits) do
    local status = {
      index = index,
      name = split.name,
      missing = index == current_index and current_missing or {},
      missing_error = index == current_index and current_error_message or nil,
      is_current = index == current_index,
      is_ready_to_complete = index == current_index and current_error_message == nil and #current_missing == 0,
      completed_elapsed_ticks = split.completed_elapsed_ticks,
      icon_groups = {}
    }

    if index == current_index - 1 then
      local group = icon_group(previous_leftover, {
        tone = "alert",
        sort_mode = "eta",
        kind = "previous-leftover"
      })
      if group then
        status.icon_groups[#status.icon_groups + 1] = group
      end
      statuses.previous = status
    elseif index == current_index then
      local remaining_group = icon_group(current_missing, {
        tone = "normal",
        sort_mode = "eta",
        kind = "remaining-work"
      })
      local placement_group = icon_group(current_placement_progress, {
        tone = "normal",
        sort_mode = "remaining",
        kind = "placement-progress"
      })
      local research_group = icon_group(current_research_progress, {
        tone = "normal",
        sort_mode = "eta",
        kind = "research-production"
      })
      if remaining_group then
        status.icon_groups[#status.icon_groups + 1] = remaining_group
      end
      if placement_group then
        status.icon_groups[#status.icon_groups + 1] = placement_group
      end
      if research_group then
        status.icon_groups[#status.icon_groups + 1] = research_group
      end
      statuses.current = status
    elseif index == current_index + 1 then
      local group = icon_group(next_split_readiness, {
        tone = "normal",
        sort_mode = "progress",
        kind = "next-split-readiness"
      })
      if group then
        status.icon_groups[#status.icon_groups + 1] = group
      end
      statuses.upcoming[#statuses.upcoming + 1] = status
    elseif index > current_index then
      statuses.upcoming[#statuses.upcoming + 1] = status
    end
  end

  return statuses
end

return M
