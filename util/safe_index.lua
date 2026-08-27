local M = {}

function M.get(root, key)
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

function M.call(target, method_name, ...)
  local method = M.get(target, method_name)
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

return M
