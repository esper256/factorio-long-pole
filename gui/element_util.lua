local M = {}

function M.destroy_children(element)
  if not element then
    return
  end

  local children = element.children
  if not children then
    return
  end

  for index = #children, 1, -1 do
    local child = children[index]
    if child then
      child.destroy()
    end
  end
end

return M
