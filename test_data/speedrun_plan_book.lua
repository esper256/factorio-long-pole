-- LuaRecord-shaped snapshot of test_data/speedrun_plan_blueprint.txt.
-- Placement counts are decoded from the export; do not hand-edit them.
local function entities(counts)
  local list = {}
  local names = {}
  for name in pairs(counts) do
    names[#names + 1] = name
  end
  table.sort(names)
  for _, name in ipairs(names) do
    for _ = 1, counts[name] do
      list[#list + 1] = { name = name }
    end
  end
  return list
end

local function lp(body)
  return table.concat({
    "====== long-pole data-begin ======",
    "# Comments and blank lines are ignored.",
    body,
    "====== long-pole data-end ======"
  }, "\n")
end

local function blueprint(label, description, counts)
  return {
    type = "blueprint",
    label = label,
    blueprint_description = description or "",
    get_blueprint_entities = function()
      return entities(counts)
    end
  }
end

local function split_book(label, description, inner_label, counts)
  return {
    type = "blueprint-book",
    label = label,
    blueprint_description = description,
    contents = {
      [0] = blueprint(inner_label, "", counts)
    }
  }
end

return {
  object_name = "LuaRecord",
  type = "blueprint-book",
  label = "100% DS Speedrun [LP]",
  contents = {
    [0] = split_book(
      "First burner",
      lp("item coal 20"),
      "First Burner",
      { ["stone-furnace"] = 1, ["burner-mining-drill"] = 1 }
    ),
    [1] = split_book(
      "Second burner",
      lp(""),
      "First Burner",
      { ["stone-furnace"] = 1, ["burner-mining-drill"] = 1 }
    ),
    [2] = {
      type = "deconstruction-planner",
      label = "Mine coal rocks",
      settings = {
        description = lp("item coal 300")
      }
    },
    [3] = split_book(
      "Copper Hand Smelter",
      lp("item copper-ore 12\nitem lab 1\nitem automation-science-pack 10"),
      "",
      { ["stone-furnace"] = 2 }
    ),
    [4] = split_book(
      "Power and First Lab",
      lp("research automation\nitem wood 100\nitem iron-plate 9\nitem iron-gear-wheel 5\nitem electronic-circuit 3"),
      "",
      {
        ["offshore-pump"] = 1,
        ["steam-engine"] = 1,
        boiler = 1,
        lab = 1,
        ["small-electric-pole"] = 1
      }
    ),
    [5] = blueprint("First assembler", lp("item small-electric-pole 20"), {
      ["assembling-machine-1"] = 1
    }),
    [6] = blueprint("Lazy Handfeed", "", {
      ["assembling-machine-1"] = 12,
      ["small-electric-pole"] = 4
    }),
    [7] = blueprint("Half-lane mine", "", {
      ["electric-mining-drill"] = 15,
      ["transport-belt"] = 25,
      ["small-electric-pole"] = 4
    }),
    [8] = blueprint("Lazy intermediate mall", "", {
      ["transport-belt"] = 176,
      inserter = 107,
      ["underground-belt"] = 3,
      ["small-electric-pole"] = 34,
      ["stone-furnace"] = 34,
      ["assembling-machine-1"] = 8,
      ["iron-chest"] = 6
    }),
    [9] = blueprint("Half-lane mine", "", {
      ["electric-mining-drill"] = 15,
      ["transport-belt"] = 25,
      ["small-electric-pole"] = 4
    })
  }
}
