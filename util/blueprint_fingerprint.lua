local M = {}

local function copy_path(path)
  local copied = {}
  for index, entry in ipairs(path or {}) do
    copied[index] = entry
  end
  return copied
end

local function normalize_summary(entity_summary)
  local normalized = {}
  for _, entry in ipairs(entity_summary or {}) do
    if entry.name and entry.name ~= "" then
      normalized[#normalized + 1] = {
        name = entry.name,
        count = math.max(1, math.floor(tonumber(entry.count) or 1))
      }
    end
  end
  return normalized
end

function M.from_entity_summary(entity_summary)
  local parts = {}
  -- This fingerprint is intentionally lossy. It is only a stable content hint
  -- for blueprint symlink recovery, not proof that two layouts are identical.
  for _, entry in ipairs(normalize_summary(entity_summary)) do
    parts[#parts + 1] = ("%s:%d"):format(entry.name, entry.count)
  end
  return table.concat(parts, ";")
end

function M.entity_summary_from_blueprint_fingerprint(blueprint_fingerprint)
  local summary = {}
  local total = 0
  if not blueprint_fingerprint or blueprint_fingerprint == "" then
    return summary, total
  end

  for entry_text in blueprint_fingerprint:gmatch("[^;]+") do
    local name, count_text = entry_text:match("^([^:]+):(.+)$")
    local count = math.floor(tonumber(count_text) or 0)
    if name and name ~= "" and count > 0 then
      summary[#summary + 1] = {
        name = name,
        count = count
      }
      total = total + count
    end
  end

  return summary, total
end

function M.extract_blueprint_fingerprint(blueprint, blueprint_symlink)
  local blueprint_name = nil
  if type(blueprint) == "table" then
    blueprint_name = blueprint.name or blueprint.blueprint_name or blueprint.label
  end

  local entity_summary = {}
  local entity_count = 0
  if type(blueprint) == "table" then
    if type(blueprint.get_blueprint_entities) == "function" then
      local entities = blueprint.get_blueprint_entities() or {}
      local counts = {}
      for _, entity in ipairs(entities) do
        if entity.name and entity.name ~= "" then
          counts[entity.name] = (counts[entity.name] or 0) + 1
        end
      end
      for name, count in pairs(counts) do
        entity_summary[#entity_summary + 1] = {name = name, count = count}
      end
      table.sort(entity_summary, function(a, b)
        if a.count == b.count then
          return a.name < b.name
        end
        return a.count > b.count
      end)
      entity_count = #entities
    else
      entity_summary = normalize_summary(blueprint.entity_summary)
      if type(blueprint.entity_count) == "number" then
        entity_count = math.max(0, math.floor(blueprint.entity_count))
      else
        for _, entry in ipairs(entity_summary) do
          entity_count = entity_count + entry.count
        end
      end
    end
  end

  return {
    blueprint_name = blueprint_name,
    library_root = blueprint_symlink and blueprint_symlink.library_root or nil,
    inside_books = copy_path(blueprint_symlink and blueprint_symlink.inside_books or nil),
    blueprint_slot = blueprint_symlink and blueprint_symlink.blueprint_slot or nil,
    blueprint_fingerprint = M.from_entity_summary(entity_summary),
    entity_summary = entity_summary,
    entity_count = entity_count
  }
end

function M.match_fraction(blueprint, blueprint_fingerprint, blueprint_symlink)
  local expected = blueprint_fingerprint
  if type(expected) == "table" then
    expected = expected.blueprint_fingerprint
  end

  if type(expected) ~= "string" or expected == "" then
    return 0
  end

  local extracted = M.extract_blueprint_fingerprint(blueprint, blueprint_symlink)
  if extracted.blueprint_fingerprint == expected then
    return 1.0
  end

  return 0.0
end

return M
