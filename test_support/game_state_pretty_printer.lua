-- Deterministic text rendering for inspecting game_state in tests and debug UI.
local game_state = require("game_state.game_state")

local M = {}

local function append(lines, text)
  lines[#lines + 1] = text
end

local function format_product_row(product_name, entry)
  return ("  product %-22s produced=%-5d consumed=%-5d placed=%-5d destroyed=%-5d loose_stock=%-5d"):format(
    product_name,
    game_state.total_products_produced(entry),
    entry.consumed or 0,
    entry.placed or 0,
    entry.destroyed or 0,
    game_state.loose_stock(entry)
  )
end

local function format_placed_entity_row(entity_name, entry)
  return ("  placed_entity %-15s placed=%-5d destroyed=%-5d"):format(
    entity_name,
    entry.placed or 0,
    entry.destroyed or 0
  )
end

local function format_research_row(technology_name, entry)
  return ("  research %-20s researched=%-5s progress=%.2f"):format(
    technology_name,
    tostring(entry.researched == true),
    entry.progress or 0
  )
end

function M.render(state)
  local lines = {}
  append(lines, ("game_state storage_version=%d tick=%d"):format(
    state.storage_version or 0,
    state.clock and state.clock.tick or 0
  ))

  for _, surface_name in ipairs(game_state.sorted_surface_names(state)) do
    local surface = state.surfaces[surface_name]
    append(lines, ("surface %s"):format(surface_name))

    for _, product_name in ipairs(game_state.sorted_product_names(surface)) do
      append(lines, format_product_row(product_name, surface.products[product_name]))
    end

    for _, entity_name in ipairs(game_state.sorted_placed_entity_names(surface)) do
      append(lines, format_placed_entity_row(entity_name, surface.placed_entities[entity_name]))
    end

  end

  for _, technology_name in ipairs(game_state.sorted_research_names(state)) do
    append(lines, format_research_row(technology_name, state.research[technology_name]))
  end

  return table.concat(lines, "\n")
end

return M
