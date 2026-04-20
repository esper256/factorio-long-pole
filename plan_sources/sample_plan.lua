local M = {}

function M.load()
  return {
    {
      name = "Starter Burners",
      items = {
        {name = "burner-mining-drill", count = 2},
        {name = "stone-furnace", count = 2},
        {name = "wood", count = 8}
      },
      blueprints = {
        {name = "Starter burner pair"}
      },
      technologies = {},
      notes = "Open on coal, hand-feed both burners, and avoid overmining stone."
    },
    {
      name = "First Power",
      items = {
        {name = "boiler", count = 1},
        {name = "steam-engine", count = 1},
        {name = "small-electric-pole", count = 6}
      },
      blueprints = {
        {name = "Power block"},
        {name = "Lab stub"}
      },
      technologies = {
        {name = "automation"}
      },
      notes = "Route iron into gears first so offshore pump through lab stays buildable on time."
    }
  }
end

return M
