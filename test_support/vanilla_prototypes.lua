-- Early-game vanilla prototypes needed to load and walk the exported plan.
local M = {}

local function placeable(type_name, item_name)
  return {
    type = type_name,
    items_to_place_this = {
      { name = item_name or type_name, count = 1 }
    }
  }
end

local function recipe(name, energy, categories, ingredients, products)
  return {
    name = name,
    energy = energy,
    categories = categories,
    ingredients = ingredients,
    products = products or { { name = name, amount = 1 } }
  }
end

local function item_ing(name, amount)
  return { type = "item", name = name, amount = amount }
end

function M.entity()
  return {
    ["stone-furnace"] = placeable("furnace", "stone-furnace"),
    ["burner-mining-drill"] = placeable("mining-drill", "burner-mining-drill"),
    ["electric-mining-drill"] = placeable("mining-drill", "electric-mining-drill"),
    lab = placeable("lab", "lab"),
    ["offshore-pump"] = placeable("offshore-pump", "offshore-pump"),
    ["steam-engine"] = placeable("generator", "steam-engine"),
    boiler = placeable("boiler", "boiler"),
    ["small-electric-pole"] = placeable("electric-pole", "small-electric-pole"),
    ["assembling-machine-1"] = placeable("assembling-machine", "assembling-machine-1"),
    ["transport-belt"] = placeable("transport-belt", "transport-belt"),
    inserter = placeable("inserter", "inserter"),
    ["underground-belt"] = placeable("underground-belt", "underground-belt"),
    ["iron-chest"] = placeable("container", "iron-chest"),
    pipe = placeable("pipe", "pipe"),
    ["tree-01"] = { type = "tree" },
    ["huge-rock"] = { type = "simple-entity" },
    ["rock-big"] = { type = "simple-entity" },
    ["crash-site-chest"] = { type = "container" },
    ["copper-ore"] = { type = "resource", resource_category = "basic-solid" },
    ["iron-ore"] = { type = "resource", resource_category = "basic-solid" },
    coal = { type = "resource", resource_category = "basic-solid" },
    stone = { type = "resource", resource_category = "basic-solid" }
  }
end

function M.recipe()
  return {
    ["stone-furnace"] = recipe("stone-furnace", 0.5, { "crafting" }, { item_ing("stone", 5) }),
    ["burner-mining-drill"] = recipe("burner-mining-drill", 2, { "crafting" }, {
      item_ing("iron-gear-wheel", 3),
      item_ing("iron-plate", 3),
      item_ing("stone-furnace", 1)
    }),
    ["iron-plate"] = recipe("iron-plate", 3.2, { "smelting" }, { item_ing("iron-ore", 1) }),
    ["copper-plate"] = recipe("copper-plate", 3.2, { "smelting" }, { item_ing("copper-ore", 1) }),
    ["copper-cable"] = recipe("copper-cable", 0.5, { "crafting" }, { item_ing("copper-plate", 1) }, {
      { name = "copper-cable", amount = 2 }
    }),
    ["iron-gear-wheel"] = recipe("iron-gear-wheel", 0.5, { "crafting" }, { item_ing("iron-plate", 2) }),
    ["electronic-circuit"] = recipe("electronic-circuit", 0.5, { "crafting" }, {
      item_ing("iron-plate", 1),
      item_ing("copper-cable", 3)
    }),
    ["transport-belt"] = recipe("transport-belt", 0.5, { "crafting" }, {
      item_ing("iron-plate", 1),
      item_ing("iron-gear-wheel", 1)
    }, { { name = "transport-belt", amount = 2 } }),
    ["underground-belt"] = recipe("underground-belt", 1, { "crafting" }, {
      item_ing("iron-gear-wheel", 5),
      item_ing("transport-belt", 10)
    }, { { name = "underground-belt", amount = 2 } }),
    inserter = recipe("inserter", 0.5, { "crafting" }, {
      item_ing("electronic-circuit", 1),
      item_ing("iron-gear-wheel", 1),
      item_ing("iron-plate", 1)
    }),
    lab = recipe("lab", 2, { "crafting" }, {
      item_ing("electronic-circuit", 10),
      item_ing("iron-gear-wheel", 10),
      item_ing("transport-belt", 4)
    }),
    ["assembling-machine-1"] = recipe("assembling-machine-1", 0.5, { "crafting" }, {
      item_ing("electronic-circuit", 3),
      item_ing("iron-gear-wheel", 5),
      item_ing("iron-plate", 9)
    }),
    ["electric-mining-drill"] = recipe("electric-mining-drill", 2, { "crafting" }, {
      item_ing("electronic-circuit", 3),
      item_ing("iron-gear-wheel", 5),
      item_ing("iron-plate", 10)
    }),
    ["small-electric-pole"] = recipe("small-electric-pole", 0.5, { "crafting" }, {
      item_ing("wood", 1),
      item_ing("copper-cable", 2)
    }),
    ["iron-chest"] = recipe("iron-chest", 0.5, { "crafting" }, { item_ing("iron-plate", 8) }),
    pipe = recipe("pipe", 0.5, { "crafting" }, { item_ing("iron-plate", 1) }),
    ["offshore-pump"] = recipe("offshore-pump", 0.5, { "crafting" }, {
      item_ing("iron-gear-wheel", 1),
      item_ing("electronic-circuit", 2),
      item_ing("pipe", 1)
    }),
    boiler = recipe("boiler", 0.5, { "crafting" }, {
      item_ing("stone-furnace", 1),
      item_ing("pipe", 4)
    }),
    ["steam-engine"] = recipe("steam-engine", 0.5, { "crafting" }, {
      item_ing("iron-gear-wheel", 8),
      item_ing("iron-plate", 5),
      item_ing("pipe", 5)
    }),
    ["automation-science-pack"] = recipe("automation-science-pack", 5, { "crafting" }, {
      item_ing("copper-plate", 1),
      item_ing("iron-gear-wheel", 1)
    })
  }
end

function M.technology()
  return {
    automation = {
      name = "automation",
      researched = false,
      research_unit_count = 10,
      research_unit_ingredients = {
        { type = "item", name = "automation-science-pack", amount = 1 }
      }
    }
  }
end

function M.item()
  return setmetatable({}, {
    __index = function(map, name)
      local item = { type = "item", name = name }
      map[name] = item
      return item
    end
  })
end

function M.fluid()
  return {
    water = { type = "fluid", name = "water" },
    steam = { type = "fluid", name = "steam" }
  }
end

return M
