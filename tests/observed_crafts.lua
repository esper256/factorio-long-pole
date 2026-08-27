-- Observed recipe mix is the currently set crafting-machine recipes, weighted
-- by crafting speed, plus the player's crafting queue.
game = {
  forces = {
    player = { name = "player" }
  },
  surfaces = {
    {
      name = "nauvis",
      find_entities_filtered = function()
        return {
          {
            get_recipe = function()
              return { name = "basic-oil-processing" }
            end,
            crafting_speed = 1
          },
          {
            get_recipe = function()
              return { name = "advanced-oil-processing" }
            end,
            crafting_speed = 3
          },
          {
            get_recipe = function()
              return nil
            end,
            crafting_speed = 1
          }
        }
      end
    }
  },
  players = {
    {
      crafting_queue = {
        { recipe = "iron-gear-wheel", count = 4 }
      }
    }
  }
}

local observed_crafts = require("progress_analysis.observed_crafts")
local snapshot = observed_crafts.snapshot()
assert(snapshot["basic-oil-processing"] == 1)
assert(snapshot["advanced-oil-processing"] == 3)
assert(snapshot["iron-gear-wheel"] == 4)
assert(snapshot["petroleum-gas"] == nil)
