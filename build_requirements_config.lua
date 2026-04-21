local M = {}

local function copy_set(source)
  local copied = {}
  for key, value in pairs(source or {}) do
    copied[key] = value
  end
  return copied
end

local function merge_set(base, extra)
  local merged = copy_set(base)
  for key, value in pairs(extra or {}) do
    merged[key] = value
  end
  return merged
end

M.raw_resources_by_planet = {
  nauvis = {
    ["item:wood"] = true,
    ["item:coal"] = true,
    ["item:iron-ore"] = true,
    ["item:copper-ore"] = true,
    ["item:stone"] = true,
    ["item:uranium-ore"] = true,
    ["fluid:crude-oil"] = true,
    ["fluid:water"] = true
  },
  vulcanus = {
    ["item:calcite"] = true,
    ["item:coal"] = true,
    ["item:tungsten-ore"] = true,
    ["fluid:lava"] = true
  },
  fulgora = {
    ["item:scrap"] = true,
    ["fluid:heavy-oil"] = true
  },
  gleba = {
    ["item:yumako"] = true,
    ["item:jellynut"] = true,
    ["fluid:water"] = true,
    ["item:pentapod-egg"] = true
  },
  aquilo = {
    ["fluid:ammoniac"] = true
  }
}

M.hidden_raw_resources_by_planet = {
  nauvis = {
    ["fluid:water"] = true
  },
  vulcanus = {
    ["fluid:lava"] = true
  },
  fulgora = {
    ["fluid:heavy-oil"] = true
  },
  gleba = {
    ["fluid:water"] = true
  },
  aquilo = {
    ["fluid:ammoniac"] = true
  }
}

-- Raw-cost expansion uses an explicit recipe-category allowlist per planet.
-- If a category is not listed for a planet here, it is not considered valid on
-- that planet. This prevents optional Space Age categories such as crushing or
-- recycling from leaking into unrelated production paths just because they
-- happen to exist in the prototype set.
local COMMON_FACTORY_CATEGORIES = {
  ["basic-crafting"] = true,
  ["crafting"] = true,
  ["advanced-crafting"] = true,
  ["crafting-with-fluid"] = true,
  ["pressing"] = true,
  ["smelting"] = true,
  ["chemistry"] = true,
  ["chemistry-or-cryogenics"] = true,
  ["oil-processing"] = true,
  ["electronics"] = true,
  ["electronics-or-assembling"] = true,
  ["electronics-with-fluid"] = true,
  ["metallurgy-or-assembling"] = true,
  ["crafting-with-fluid-or-metallurgy"] = true,
  ["centrifuging"] = true,
  ["rocket-building"] = true
}

M.allowed_recipe_categories_by_planet = {
  nauvis = copy_set(COMMON_FACTORY_CATEGORIES),
  vulcanus = merge_set(COMMON_FACTORY_CATEGORIES, {
    metallurgy = true
  }),
  fulgora = merge_set(COMMON_FACTORY_CATEGORIES, {
    recycling = true,
    ["recycling-or-hand-crafting"] = true
  }),
  gleba = copy_set(COMMON_FACTORY_CATEGORIES),
  aquilo = copy_set(COMMON_FACTORY_CATEGORIES)
}

-- Explicitly ignore prototypes that should never appear in requirement
-- summaries. This is a good place to suppress editor-only or map-only entries.
M.ignored_requirement_keys = {
  ["item:loader"] = true,
  ["entity:loader"] = true
}

return M
