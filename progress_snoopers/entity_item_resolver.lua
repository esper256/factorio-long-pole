local M = {}

local function first_place_item(items_to_place_this)
  if type(items_to_place_this) ~= "table" then
    return nil
  end

  local first = items_to_place_this[1]
  if type(first) == "table" then
    return first.name
  end

  return first
end

function M.resolve_item_name(event, entity)
  if event and type(event.item_name) == "string" and event.item_name ~= "" then
    return event.item_name
  end

  local stack = event and event.stack or nil
  if stack and stack.valid_for_read and stack.name and stack.name ~= "" then
    return stack.name
  end

  local prototype = entity and entity.prototype or nil
  local item_name = first_place_item(prototype and prototype.items_to_place_this or nil)
  if item_name and item_name ~= "" then
    return item_name
  end

  if entity and entity.name and entity.name ~= "" then
    return entity.name
  end

  return nil
end

return M
