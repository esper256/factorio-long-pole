local M = {}

function M.load()
  return {
    {
      name = "Starter Burners",
      items = {
        {name = "burner-mining-drill", count = 2},
        {name = "stone-furnace", count = 2}
      },
      blueprints = {},
      technologies = {},
      notes = "Temporary sample data until blueprint-book import exists."
    },
    {
      name = "First Power",
      items = {
        {name = "boiler", count = 1},
        {name = "steam-engine", count = 1},
        {name = "small-electric-pole", count = 6}
      },
      blueprints = {},
      technologies = {},
      notes = "Replace with imported run-plan data once persistence is wired up."
    }
  }
end

return M
