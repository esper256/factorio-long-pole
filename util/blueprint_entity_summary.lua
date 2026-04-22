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

  -- Stored summaries are reused across saves and tests, so their order needs to
  -- be deterministic even though the intermediate counts table is not.
  table.sort(summary, function(a, b)
    if a.count == b.count then
      return a.name < b.name
    end
    return a.count > b.count
  end)

  return summary
end

function M.summarize_entities(entities)
  return summarize_blueprint_entities(entities)
end

return M
