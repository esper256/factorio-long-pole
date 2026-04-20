local M = {}

local function copy_entries(entries)
  local copied = {}
  for index, entry in ipairs(entries or {}) do
    local item_copy = {}
    for key, value in pairs(entry) do
      item_copy[key] = value
    end
    copied[index] = item_copy
  end
  return copied
end

local function normalize_split(split, fallback_name)
  split.name = split.name or fallback_name or "Untitled Split"
  split.items = copy_entries(split.items)
  split.blueprints = copy_entries(split.blueprints)
  split.technologies = copy_entries(split.technologies)
  split.notes = split.notes or ""
  return split
end

local function clamp_current_index(state)
  if #state.splits == 0 then
    state.current_split_index = 1
    return
  end

  if state.current_split_index < 1 then
    state.current_split_index = 1
  elseif state.current_split_index > #state.splits then
    state.current_split_index = #state.splits
  end
end

function M.init(state)
  state.inventory = state.inventory or {}
  state.splits = state.splits or {}
  state.current_split_index = state.current_split_index or 1
  state.editor_selection = state.editor_selection or {}
  state.entity_events = state.entity_events or {}

  for index, split in ipairs(state.splits) do
    state.splits[index] = normalize_split(split, ("Split %d"):format(index))
  end

  clamp_current_index(state)
end

function M.create_split(name)
  return normalize_split({
    name = name,
    items = {},
    blueprints = {},
    technologies = {}
  }, name)
end

function M.add_split(state, name)
  local split = M.create_split(name or ("Split %d"):format(#state.splits + 1))
  table.insert(state.splits, split)
  clamp_current_index(state)
  return #state.splits, split
end

function M.get_split(state, index)
  return state.splits[index]
end

function M.get_selected_split_index(state, player_index)
  local selected = state.editor_selection[player_index]
  if selected and state.splits[selected] then
    return selected
  end
  return state.current_split_index
end

function M.set_selected_split_index(state, player_index, split_index)
  if state.splits[split_index] then
    state.editor_selection[player_index] = split_index
    return true
  end
  return false
end

function M.rename_split(state, split_index, name)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  local trimmed = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  split.name = trimmed ~= "" and trimmed or ("Split %d"):format(split_index)
  return true
end

function M.on_entity_changed(state, event)
  local entity = event.entity or event.created_entity
  state.entity_events[#state.entity_events + 1] = {
    tick = event.tick,
    unit_number = entity and entity.unit_number or nil,
    name = entity and entity.name or nil
  }
end

local function summarize_requirements(split)
  local missing = {}
  for _, item in ipairs(split.items) do
    missing[#missing + 1] = {
      name = item.name,
      count = item.count or 0,
      predicted_seconds = math.max(15, (item.count or 0) * 5)
    }
  end

  table.sort(missing, function(a, b)
    if a.predicted_seconds == b.predicted_seconds then
      return a.name < b.name
    end
    return a.predicted_seconds > b.predicted_seconds
  end)

  return missing
end

function M.get_split_status(state)
  clamp_current_index(state)

  local statuses = {
    previous = nil,
    current = nil,
    upcoming = {}
  }

  local current_index = state.current_split_index
  for index, split in ipairs(state.splits) do
    local status = {
      index = index,
      name = split.name,
      delta_caption = "--",
      missing = summarize_requirements(split),
      is_current = index == current_index,
      is_complete = #split.items == 0 and #split.blueprints == 0 and #split.technologies == 0
    }

    if index == current_index - 1 then
      statuses.previous = status
    elseif index == current_index then
      statuses.current = status
    elseif index > current_index then
      statuses.upcoming[#statuses.upcoming + 1] = status
    end
  end

  return statuses
end

function M.advance_split(state)
  clamp_current_index(state)
  if state.current_split_index < #state.splits then
    state.current_split_index = state.current_split_index + 1
    return true
  end
  return false
end

return M
