local M = {}

local function safe_index(root, key)
  if root == nil then
    return nil
  end

  local ok, value = pcall(function()
    return root[key]
  end)
  if ok then
    return value
  end

  return nil
end

local function append_path(path, value)
  local next_path = {}
  for index, entry in ipairs(path or {}) do
    next_path[index] = entry
  end
  next_path[#next_path + 1] = value
  return next_path
end

local function collect_ordered_records(records)
  local ordered = {}
  for index, record in pairs(records or {}) do
    ordered[#ordered + 1] = {
      index = index,
      record = record
    }
  end

  table.sort(ordered, function(a, b)
    return a.index < b.index
  end)

  return ordered
end

local function record_label(record)
  local label = safe_index(record, "label")
  if type(label) ~= "string" or label == "" then
    return nil
  end

  return label
end

local function find_in_records(records, export_string, context)
  for _, entry in ipairs(collect_ordered_records(records)) do
    local record = entry.record
    if record and safe_index(record, "valid") then
      local record_type = safe_index(record, "type")
      if record_type == "blueprint" and record.is_blueprint_setup and record:is_blueprint_setup() then
        if record.export_record and record:export_record() == export_string then
          return {
            library_root = context.library_root,
            inside_books = context.inside_books or {},
            blueprint_slot = entry.index
          }
        end
      elseif record_type == "blueprint-book" and safe_index(record, "contents") then
        local next_context = {
          library_root = context.library_root,
          inside_books = context.inside_books or {}
        }
        local label = record_label(record)
        if label then
          next_context.inside_books = append_path(next_context.inside_books, label)
        end

        local match = find_in_records(safe_index(record, "contents"), export_string, next_context)
        if match then
          return match
        end
      end
    end
  end

  return nil
end

local function find_first_record_matching(records, predicate, context)
  for _, entry in ipairs(collect_ordered_records(records)) do
    local record = entry.record
    if record and safe_index(record, "valid") then
      local record_type = safe_index(record, "type")
      if predicate(record, entry.index, context) then
        return {
          record = record,
          library_root = context.library_root,
          inside_books = context.inside_books or {},
          slot = entry.index
        }
      end

      if record_type == "blueprint-book" and safe_index(record, "contents") then
        local next_context = {
          library_root = context.library_root,
          inside_books = context.inside_books or {}
        }
        local label = record_label(record)
        if label then
          next_context.inside_books = append_path(next_context.inside_books, label)
        end

        local match = find_first_record_matching(safe_index(record, "contents"), predicate, next_context)
        if match then
          return match
        end
      end
    end
  end

  return nil
end

function M.find_blueprint_path_by_export(player, export_string, game_script)
  if not player or type(export_string) ~= "string" or export_string == "" then
    return nil
  end

  local libraries = {
    {
      root_name = "player-blueprints",
      records = player.blueprints
    },
    {
      root_name = "game-blueprints",
      records = game_script and game_script.blueprints or nil
    }
  }

  for _, library in ipairs(libraries) do
    local match = find_in_records(library.records, export_string, {
      library_root = library.root_name,
      inside_books = {}
    })
    if match then
      return match
    end
  end

  return nil
end

function M.find_first_blueprint_book_matching(player, game_script, predicate)
  if not player or type(predicate) ~= "function" then
    return nil
  end

  local libraries = {
    {
      root_name = "player-blueprints",
      records = player.blueprints
    },
    {
      root_name = "game-blueprints",
      records = game_script and game_script.blueprints or nil
    }
  }

  for _, library in ipairs(libraries) do
    local match = find_first_record_matching(library.records, predicate, {
      library_root = library.root_name,
      inside_books = {}
    })
    if match then
      return match
    end
  end

  return nil
end

function M.find_first_player_blueprint_book_matching(player, predicate)
  return M.find_first_blueprint_book_matching(player, nil, predicate)
end

return M
