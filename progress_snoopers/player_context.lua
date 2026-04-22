local M = {}

function M.get_player(event)
  if not (game and game.get_player and event and event.player_index) then
    return nil
  end

  return game.get_player(event.player_index)
end

function M.resolve_force_name(event, entity)
  local player = M.get_player(event)
  -- Prefer player context when available so controller-specific force overrides
  -- beat whatever fallback metadata the event happened to include.
  if player and player.force and player.force.name then
    return player.force.name
  end

  if entity and entity.force and entity.force.name then
    return entity.force.name
  end

  return event and event.force_name or nil
end

function M.resolve_surface_name(event, entity)
  -- Surface can come from the placed/mined entity even when the player has moved
  -- away by the time the event is handled.
  if entity and entity.surface and entity.surface.name then
    return entity.surface.name
  end

  if entity and entity.surface_name then
    return entity.surface_name
  end

  local player = M.get_player(event)
  if player and player.surface and player.surface.name then
    return player.surface.name
  end

  return event and event.surface_name or nil
end

return M
