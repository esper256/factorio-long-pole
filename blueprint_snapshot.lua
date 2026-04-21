local M = {}

local function summarize_blueprint_entities(entities)
  local counts_by_name = {}
  for _, entity in ipairs(entities or {}) do
    if entity.name and entity.name ~= "" then
      counts_by_name[entity.name] = (counts_by_name[entity.name] or 0) + 1
    end
  end

  local summary = {}
  for name, count in pairs(counts_by_name) do
    summary[#summary + 1] = {
      name = name,
      count = count
    }
  end

  table.sort(summary, function(a, b)
    if a.count == b.count then
      return a.name < b.name
    end
    return a.count > b.count
  end)

  return summary
end

local function copy_blueprint_record(blueprint)
  local copied = {}
  for key, value in pairs(blueprint or {}) do
    copied[key] = value
  end
  return copied
end

function M.summarize_entities(entities)
  return summarize_blueprint_entities(entities)
end

function M.resolve_name_from_export(export_string, fallback_name)
  if not (game and game.create_inventory and export_string and export_string ~= "") then
    return fallback_name
  end

  local inventory = game.create_inventory(1)
  if not inventory then
    return fallback_name
  end

  local name = fallback_name
  local stack = inventory[1]
  if stack and stack.valid and stack.import_stack(export_string) <= 0 then
    if stack.label and stack.label ~= "" then
      name = stack.label
    end
  end

  inventory.destroy()
  return name
end

function M.refresh_blueprint_record(blueprint)
  local refreshed = copy_blueprint_record(blueprint)

  if not (game and game.create_inventory and refreshed.export_string and refreshed.export_string ~= "") then
    if not refreshed.name or refreshed.name == "" then
      refreshed.name = "Unnamed Blueprint"
    end
    return refreshed
  end

  local inventory = game.create_inventory(1)
  if not inventory then
    if not refreshed.name or refreshed.name == "" then
      refreshed.name = "Unnamed Blueprint"
    end
    return refreshed
  end

  local stack = inventory[1]
  refreshed.entity_count = nil
  refreshed.entity_summary = nil
  if stack and stack.valid and stack.import_stack(refreshed.export_string) <= 0 and stack.is_blueprint then
    refreshed.entity_count = stack.get_blueprint_entity_count()
    refreshed.entity_summary = summarize_blueprint_entities(stack.get_blueprint_entities() or {})
    if stack.label and stack.label ~= "" then
      refreshed.name = stack.label
    end
  end

  inventory.destroy()

  if not refreshed.name or refreshed.name == "" then
    refreshed.name = "Unnamed Blueprint"
  end

  return refreshed
end

function M.refresh_plan_blueprints(plan)
  if type(plan) ~= "table" then
    return plan
  end

  for _, split in ipairs(plan.splits or {}) do
    local refreshed_blueprints = {}
    for index, blueprint in ipairs(split.blueprints or {}) do
      refreshed_blueprints[index] = M.refresh_blueprint_record(blueprint)
    end
    split.blueprints = refreshed_blueprints
  end

  return plan
end

return M
