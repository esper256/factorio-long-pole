local M = {}

function M.available_surfaces()
  if rawget(_G, "script") and script.active_mods and script.active_mods["space-age"] then
    return {"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"}
  end

  return {"nauvis"}
end

function M.normalize_split_surface(split)
  local surfaces = M.available_surfaces()
  for _, surface_name in ipairs(surfaces) do
    if split.surface == surface_name then
      return surface_name
    end
  end

  return surfaces[1]
end

function M.next_surface_name(current_surface)
  local surfaces = M.available_surfaces()
  local current_index = 1
  for index, surface_name in ipairs(surfaces) do
    if surface_name == current_surface then
      current_index = index
      break
    end
  end

  return surfaces[(current_index % #surfaces) + 1]
end

function M.surface_sprite_path(surface_name)
  return "space-location/" .. surface_name
end

function M.format_surface_caption(surface_name)
  return (surface_name:gsub("^%l", string.upper))
end

return M
