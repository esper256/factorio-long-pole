-- First-stab observed recipe mix (PRODUCT.md §4).
--
-- Factorio has no recipe production graph. Weight each crafting machine by
-- its current crafting_speed for the recipe it is set to, and add the
-- player's crafting queue. The heuristic blends those counts when several
-- recipes make the same product.
local M = {}

local CRAFTING_MACHINE_TYPES = {
  "assembling-machine",
  "furnace",
  "rocket-silo"
}

local function add(counts, recipe_name, weight)
  if type(recipe_name) ~= "string" or recipe_name == "" then
    return
  end
  local amount = weight or 0
  if amount <= 0 then
    return
  end
  counts[recipe_name] = (counts[recipe_name] or 0) + amount
end

local function recipe_name_of(entity)
  if not entity or entity.valid == false or not entity.get_recipe then
    return nil
  end
  local ok, recipe = pcall(function()
    return entity.get_recipe()
  end)
  if not ok or recipe == nil then
    return nil
  end
  if type(recipe) == "string" then
    return recipe
  end
  return recipe.name
end

local function queued_recipe_name(queued)
  local recipe = queued and queued.recipe
  if type(recipe) == "string" then
    return recipe
  end
  return recipe and recipe.name
end

function M.snapshot()
  local counts = {}
  if not game then
    return counts
  end

  local force = game.forces and game.forces.player
  for _, surface in pairs(game.surfaces or {}) do
    if surface.find_entities_filtered then
      local filter = { type = CRAFTING_MACHINE_TYPES }
      if force then
        filter.force = force
      end
      local machines = surface.find_entities_filtered(filter)
      for _, entity in pairs(machines) do
        add(counts, recipe_name_of(entity), entity.crafting_speed or 1)
      end
    end
  end

  for _, player in pairs(game.players or {}) do
    if player.valid ~= false and player.crafting_queue then
      for _, queued in ipairs(player.crafting_queue) do
        add(counts, queued_recipe_name(queued), queued.count or 1)
      end
    end
  end

  return counts
end

return M
