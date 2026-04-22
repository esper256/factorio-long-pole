local blueprint_fingerprint = require("util.blueprint_fingerprint")

local M = {}

-- Blueprint symlinks are only as durable as the hints we can recover from the
-- library tree, so this module searches the hinted path first and only falls
-- back to a deep scan when the intended book path does not resolve.

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

local function is_setup_blueprint(record)
  return safe_index(record, "type") == "blueprint"
    and record
    and record.is_blueprint_setup
    and record:is_blueprint_setup()
end

local function make_match(context, slot_index, record, match_fraction)
  return {
    library_root = context.library_root,
    inside_books = context.inside_books or {},
    blueprint_slot = slot_index,
    blueprint_name = record_label(record),
    match_fraction = match_fraction
  }
end

local function match_record(record, slot_index, context, target_fingerprint)
  if not is_setup_blueprint(record) then
    return nil
  end

  local symlink = {
    library_root = context.library_root,
    inside_books = context.inside_books or {},
    blueprint_slot = slot_index
  }
  local fraction = blueprint_fingerprint.match_fraction(record, target_fingerprint, symlink)
  if fraction > 0 then
    return make_match(context, slot_index, record, fraction)
  end

  return nil
end

local function find_named_child_book(records, label)
  for _, entry in ipairs(collect_ordered_records(records)) do
    local record = entry.record
    if record and safe_index(record, "valid") and safe_index(record, "type") == "blueprint-book" then
      if record_label(record) == label then
        return record, entry.index
      end
    end
  end

  return nil, nil
end

local function descend_to_hinted_book(records, context, inside_books)
  local current_records = records
  local current_context = {
    library_root = context.library_root,
    inside_books = context.inside_books or {}
  }

  for _, book_name in ipairs(inside_books or {}) do
    local record = find_named_child_book(current_records, book_name)
    if not record then
      return nil, nil
    end

    current_context = {
      library_root = current_context.library_root,
      inside_books = append_path(current_context.inside_books, book_name)
    }
    current_records = safe_index(record, "contents")
    if type(current_records) ~= "table" then
      return nil, nil
    end
  end

  return current_records, current_context
end

local function scan_records(records, context, target_fingerprint)
  for _, entry in ipairs(collect_ordered_records(records)) do
    local record = entry.record
    if record and safe_index(record, "valid") then
      local matched = match_record(record, entry.index, context, target_fingerprint)
      if matched then
        return matched
      end

      if safe_index(record, "type") == "blueprint-book" and safe_index(record, "contents") then
        local next_context = {
          library_root = context.library_root,
          inside_books = context.inside_books or {}
        }
        local label = record_label(record)
        if label then
          next_context.inside_books = append_path(next_context.inside_books, label)
        end

        local nested = scan_records(safe_index(record, "contents"), next_context, target_fingerprint)
        if nested then
          return nested
        end
      end
    end
  end

  return nil
end

local function search_hinted_path(records, context, target_fingerprint)
  local hinted_records, hinted_context = descend_to_hinted_book(records, context, target_fingerprint.inside_books)
  if not hinted_records then
    return nil
  end

  local hinted_slot = target_fingerprint.blueprint_slot
  if type(hinted_slot) == "number" then
    local hinted_record = hinted_records[hinted_slot]
    if hinted_record then
      local exact = match_record(hinted_record, hinted_slot, hinted_context, target_fingerprint)
      if exact then
        return exact
      end
    end
  end

  return scan_records(hinted_records, hinted_context, target_fingerprint)
end

local function ordered_libraries(player, game_script, preferred_root)
  local libraries = {
    {
      root_name = "player-blueprints",
      records = player and player.blueprints or nil
    },
    {
      root_name = "game-blueprints",
      records = game_script and game_script.blueprints or nil
    }
  }

  if preferred_root == "game-blueprints" then
    libraries[1], libraries[2] = libraries[2], libraries[1]
  end

  return libraries
end

function M.find_blueprint_symlink_by_fingerprint(player, target_fingerprint, game_script)
  if type(target_fingerprint) ~= "table" then
    return nil
  end

  if type(target_fingerprint.blueprint_fingerprint) ~= "string" or target_fingerprint.blueprint_fingerprint == "" then
    return nil
  end

  for _, library in ipairs(ordered_libraries(player, game_script, target_fingerprint.library_root)) do
    local context = {
      library_root = library.root_name,
      inside_books = {}
    }
    local hinted_match = search_hinted_path(library.records, context, target_fingerprint)
    if hinted_match then
      return hinted_match
    end
  end

  for _, library in ipairs(ordered_libraries(player, game_script, target_fingerprint.library_root)) do
    local match = scan_records(library.records, {
      library_root = library.root_name,
      inside_books = {}
    }, target_fingerprint)
    if match then
      return match
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

function M.find_first_blueprint_book_matching(player, game_script, predicate)
  if not player or type(predicate) ~= "function" then
    return nil
  end

  local libraries = ordered_libraries(player, game_script, nil)
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
