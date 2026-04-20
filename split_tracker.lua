local M = {}

local function ensure_next_split_id(state)
  state.next_split_id = state.next_split_id or 1
  return state.next_split_id
end

local function take_next_split_id(state)
  local next_id = ensure_next_split_id(state)
  state.next_split_id = next_id + 1
  return next_id
end

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
  ensure_next_split_id(state)

  for index, split in ipairs(state.splits) do
    state.splits[index] = normalize_split(split, ("Split %d"):format(index))
    if not state.splits[index].id then
      state.splits[index].id = take_next_split_id(state)
    elseif state.splits[index].id >= state.next_split_id then
      state.next_split_id = state.splits[index].id + 1
    end
  end

  clamp_current_index(state)
end

function M.create_split(state, name)
  local split = normalize_split({
    name = name,
    items = {},
    blueprints = {},
    technologies = {}
  }, name)
  split.id = take_next_split_id(state)
  return split
end

function M.add_split(state, name)
  local split = M.create_split(state, name or ("Split %d"):format(#state.splits + 1))
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

function M.find_split_index_by_id(state, split_id)
  for index, split in ipairs(state.splits) do
    if split.id == split_id then
      return index
    end
  end

  return nil
end

function M.get_split_by_id(state, split_id)
  local split_index = M.find_split_index_by_id(state, split_id)
  if split_index then
    return state.splits[split_index], split_index
  end

  return nil, nil
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

function M.rename_split_by_id(state, split_id, name)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.rename_split(state, split_index, name)
end

function M.set_split_notes(state, split_index, notes)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  split.notes = notes or ""
  return true
end

function M.set_split_notes_by_id(state, split_id, notes)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_notes(state, split_index, notes)
end

function M.set_split_blueprints(state, split_index, blueprints)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  split.blueprints = copy_entries(blueprints)
  return true
end

function M.set_split_blueprints_by_id(state, split_id, blueprints)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_blueprints(state, split_index, blueprints)
end

function M.add_split_blueprint_by_id(state, split_id, blueprint)
  local split = M.get_split_by_id(state, split_id)
  if not split or not blueprint then
    return false
  end

  split.blueprints[#split.blueprints + 1] = copy_entries({blueprint})[1]
  return true
end

function M.replace_split_blueprint_by_id(state, split_id, blueprint_index, blueprint)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.blueprints[blueprint_index] or not blueprint then
    return false
  end

  split.blueprints[blueprint_index] = copy_entries({blueprint})[1]
  return true
end

function M.remove_split_blueprint_by_id(state, split_id, blueprint_index)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.blueprints[blueprint_index] then
    return false
  end

  table.remove(split.blueprints, blueprint_index)
  return true
end

function M.set_split_items(state, split_index, items)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  split.items = copy_entries(items)
  return true
end

function M.set_split_items_by_id(state, split_id, items)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_items(state, split_index, items)
end

function M.add_split_item_by_id(state, split_id, item)
  local split = M.get_split_by_id(state, split_id)
  if not split then
    return false
  end

  split.items[#split.items + 1] = copy_entries({item or {count = 1}})[1]
  return true
end

function M.set_split_item_name_by_id(state, split_id, item_index, item_name)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.items[item_index] then
    return false
  end

  if not item_name or item_name == "" then
    table.remove(split.items, item_index)
    return true
  end

  split.items[item_index].name = item_name
  split.items[item_index].count = split.items[item_index].count or 1
  return true
end

function M.set_split_item_count_by_id(state, split_id, item_index, count)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.items[item_index] then
    return false
  end

  split.items[item_index].count = math.max(1, math.floor(tonumber(count) or 1))
  return true
end

function M.remove_split_item_by_id(state, split_id, item_index)
  local split = M.get_split_by_id(state, split_id)
  if not split or not split.items[item_index] then
    return false
  end

  table.remove(split.items, item_index)
  return true
end

function M.set_split_technologies(state, split_index, technologies)
  local split = state.splits[split_index]
  if not split then
    return false
  end

  split.technologies = copy_entries(technologies)
  return true
end

function M.set_split_technologies_by_id(state, split_id, technologies)
  local split_index = M.find_split_index_by_id(state, split_id)
  if not split_index then
    return false
  end

  return M.set_split_technologies(state, split_index, technologies)
end

function M.move_split(state, from_index, to_index)
  if from_index == to_index then
    return false
  end

  if not state.splits[from_index] or not state.splits[to_index] then
    return false
  end

  local split = table.remove(state.splits, from_index)
  table.insert(state.splits, to_index, split)

  if state.current_split_index == from_index then
    state.current_split_index = to_index
  elseif from_index < state.current_split_index and to_index >= state.current_split_index then
    state.current_split_index = state.current_split_index - 1
  elseif from_index > state.current_split_index and to_index <= state.current_split_index then
    state.current_split_index = state.current_split_index + 1
  end

  for player_index, selected_index in pairs(state.editor_selection) do
    if selected_index == from_index then
      state.editor_selection[player_index] = to_index
    elseif from_index < selected_index and to_index >= selected_index then
      state.editor_selection[player_index] = selected_index - 1
    elseif from_index > selected_index and to_index <= selected_index then
      state.editor_selection[player_index] = selected_index + 1
    end
  end

  clamp_current_index(state)
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
    if item.name and item.name ~= "" then
      missing[#missing + 1] = {
        name = item.name,
        count = item.count or 0,
        predicted_seconds = math.max(15, (item.count or 0) * 5)
      }
    end
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
