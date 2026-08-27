local progress_tracker_store = require("progress_tracker_store")
local safe_index = require("util.safe_index")

local M = {
  id = "research-progress"
}

local function try_index(root, key)
  return safe_index.get(root, key)
end

local function split_technology_names(state)
  local names = {}
  for _, split in ipairs(state and state.splits or {}) do
    for _, technology in ipairs(split.technologies or {}) do
      if technology.name and technology.name ~= "" then
        names[technology.name] = true
      end
    end
  end
  return names
end

local function relevant_forces(runtime)
  local forces = {}
  local players = try_index(runtime, "players") or {}
  for _, player in pairs(players) do
    local force = try_index(player, "force")
    local force_name = try_index(force, "name")
    if force_name then
      forces[force_name] = force
    end
  end
  return forces
end

local function technology_progress(force, technology)
  if try_index(technology, "researched") then
    return 1
  end

  local current = try_index(force, "current_research")
  if current and try_index(current, "name") == try_index(technology, "name") then
    return tonumber(try_index(force, "research_progress")) or 0
  end

  local getter = try_index(force, "get_saved_technology_progress")
  if type(getter) == "function" then
    local ok, saved = pcall(getter, force, technology)
    if ok and type(saved) == "number" then
      return saved
    end
  end

  return tonumber(try_index(technology, "saved_progress")) or 0
end

local function count_working_labs(force, runtime)
  local surfaces = try_index(runtime, "surfaces") or {}
  local working = 0
  local found_query = false
  local working_status = rawget(_G, "defines")
  working_status = working_status and working_status.entity_status and working_status.entity_status.working

  for _, surface in pairs(surfaces) do
    local find = try_index(surface, "find_entities_filtered")
    if type(find) == "function" then
      found_query = true
      local ok, labs = pcall(find, surface, {
        type = "lab",
        force = force
      })
      if ok and type(labs) == "table" then
        for _, lab in pairs(labs) do
          local status = try_index(lab, "status")
          local crafting = try_index(lab, "is_crafting")
          local behavior = try_index(lab, "get_control_behavior")
          local has_lab_behavior = false
          if type(behavior) == "function" then
            local behavior_ok, control = pcall(behavior, lab)
            has_lab_behavior = behavior_ok and control ~= nil
          end
          if crafting == true or status == working_status or (has_lab_behavior and status == nil and crafting == nil) then
            working = working + 1
          end
        end
      end
    end
  end

  if not found_query then
    return nil
  end

  return working
end

function M.poll(state, runtime)
  local runtime_root = runtime or rawget(_G, "game")
  if not runtime_root then
    return false
  end

  local handled = false
  local wanted = split_technology_names(state)
  local forces = relevant_forces(runtime_root)

  for force_name, force in pairs(forces) do
    local current = try_index(force, "current_research")
    local current_name = try_index(current, "name")
    local current_progress = tonumber(try_index(force, "research_progress")) or 0
    handled = progress_tracker_store.set_current_research(state, force_name, current_name, current_progress) or handled

    local technologies = try_index(force, "technologies") or {}
    for technology_name in pairs(wanted) do
      local technology = try_index(technologies, technology_name)
      if technology then
        local researched = try_index(technology, "researched") == true
        handled = progress_tracker_store.set_technology_researched(state, force_name, technology_name, researched) or handled
        if not researched then
          handled = progress_tracker_store.set_research_progress(
            state,
            force_name,
            technology_name,
            technology_progress(force, technology)
          ) or handled
        end
      end
    end

    local lab_count = count_working_labs(force, runtime_root)
    if lab_count ~= nil then
      handled = progress_tracker_store.set_lab_working_count(state, force_name, lab_count) or handled
    end

    local pack_rates = {}
    for _, split in ipairs(state.splits or {}) do
      if split.surface and split.surface ~= "" then
        local snapshot = progress_tracker_store.get_surface_snapshot(state, force_name, split.surface, split.id)
        for _, entry in ipairs(snapshot.entries or {}) do
          if entry.item_name and entry.item_name:find("science%-pack", 1, false) then
            pack_rates[entry.item_name] = math.max(pack_rates[entry.item_name] or 0, entry.consumed_rate or 0)
          end
        end
      end
    end
    for item_name, rate in pairs(pack_rates) do
      handled = progress_tracker_store.set_pack_consumption_rate(state, force_name, item_name, rate) or handled
    end
  end

  return handled
end

return M
