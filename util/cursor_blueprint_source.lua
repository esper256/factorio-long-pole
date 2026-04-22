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

local function item_main_inventory_id()
  if defines and defines.inventory and defines.inventory.item_main then
    return defines.inventory.item_main
  end

  return 1
end

local function call_method(target, method_name, ...)
  local method = safe_index(target, method_name)
  if type(method) ~= "function" then
    return false, nil
  end

  local ok, result = pcall(method, target, ...)
  if ok then
    return true, result
  end

  ok, result = pcall(method, ...)
  if ok then
    return true, result
  end

  return false, nil
end

local function matches_allowed_type(source_type, allowed_types)
  if allowed_types == nil then
    return true
  end

  return allowed_types[source_type] == true
end

local function cursor_candidates(player, include_blueprint_to_setup)
  local candidates = {
    {
      carrier = "cursor_record",
      source = safe_index(player, "cursor_record")
    },
    {
      carrier = "cursor_stack",
      source = safe_index(player, "cursor_stack")
    }
  }

  if include_blueprint_to_setup then
    candidates[#candidates + 1] = {
      carrier = "blueprint_to_setup",
      source = safe_index(player, "blueprint_to_setup")
    }
  end

  return candidates
end

function M.source_is_valid(source)
  return safe_index(source, "valid_for_read") or safe_index(source, "valid")
end

function M.source_type(source)
  if safe_index(source, "is_blueprint_book") then
    return "blueprint-book"
  end

  if safe_index(source, "is_blueprint") then
    return "blueprint"
  end

  local record_type = safe_index(source, "type")
  if type(record_type) == "string" then
    return record_type
  end

  return nil
end

function M.find_matching_cursor_source(player, options)
  local settings = options or {}
  for _, candidate in ipairs(cursor_candidates(player, settings.include_blueprint_to_setup == true)) do
    local source = candidate.source
    local source_type = M.source_type(source)
    if source and M.source_is_valid(source) and matches_allowed_type(source_type, settings.allowed_types) then
      if not settings.predicate or settings.predicate(source, candidate) then
        return {
          carrier = candidate.carrier,
          source = source,
          source_type = source_type
        }
      end
    end
  end

  return nil
end

function M.find_cursor_blueprint_book(player)
  return M.find_matching_cursor_source(player, {
    allowed_types = {
      ["blueprint-book"] = true
    }
  })
end

function M.resolve_selected_blueprint(player, options)
  local settings = options or {}
  local match = M.find_matching_cursor_source(player, {
    allowed_types = {
      ["blueprint"] = true,
      ["blueprint-book"] = true
    },
    include_blueprint_to_setup = settings.include_blueprint_to_setup ~= false
  })
  if not match then
    return nil, settings.missing_message or "Hold a configured blueprint or blueprint book in the cursor first."
  end

  local source = match.source
  local source_type = match.source_type
  local source_book_label = nil
  local source_book_active_index = nil

  if source_type == "blueprint-book" then
    source_book_label = safe_index(source, "label")

    if match.carrier == "cursor_record" then
      local _, active_index = call_method(source, "get_active_index", player)
      local _, selected_record = call_method(source, "get_selected_record", player)
      if not selected_record then
        return nil, settings.no_selected_message or "The held blueprint book does not have an active blueprint selected."
      end

      source_book_active_index = active_index
      source = selected_record
      source_type = M.source_type(source)
    else
      local inventory = source.get_inventory and source.get_inventory(item_main_inventory_id()) or nil
      local active_index = safe_index(source, "active_index")
      if not (inventory and active_index and inventory[active_index] and M.source_is_valid(inventory[active_index])) then
        return nil, settings.no_selected_message or "The held blueprint book does not have an active blueprint selected."
      end

      source_book_active_index = active_index
      source = inventory[active_index]
      source_type = M.source_type(source)
    end
  end

  if source_type ~= "blueprint" then
    return nil, settings.missing_message or "Hold a configured blueprint or blueprint book in the cursor first."
  end

  local has_setup_method, is_setup = call_method(source, "is_blueprint_setup")
  if has_setup_method then
    if not is_setup then
      return nil, settings.empty_blueprint_message or "The held blueprint is empty."
    end
  else
    local _, entity_count = call_method(source, "get_blueprint_entity_count")
    if (entity_count or 0) < 1 then
      return nil, settings.empty_blueprint_message or "The held blueprint is empty."
    end
  end

  return {
    carrier = match.carrier,
    source = source,
    source_type = source_type,
    source_book_label = source_book_label,
    source_book_active_index = source_book_active_index
  }, nil
end

return M
