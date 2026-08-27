local eta = require("util.eta")

describe("eta", function()
  it("adds factory rate to a nonstop handcraft so zero-rate items stay sortable", function()
    local entries = {
      {
        kind = "item",
        name = "iron-gear-wheel",
        count = 10
      }
    }

    eta.attach(entries, {
      entries = {
        {
          item_name = "iron-gear-wheel",
          produced_rate = 30
        }
      }
    }, {
      resolve_recipe_set = function()
        return {
          {
            energy = 0.5,
            products = {
              {type = "item", name = "iron-gear-wheel", amount = 1}
            }
          }
        }
      end
    })

    -- 30/min factory + 120/min handcraft = 150/min -> 10 items in 4 seconds
    assert.is_true(math.abs(entries[1].eta_seconds - 4) < 0.0001)
    assert.are.equal("0:04", eta.format_seconds(entries[1].eta_seconds))
  end)

  it("uses lab consumption as the last step for science packs", function()
    local seconds = eta.eta_seconds_for_entry({
      kind = "item",
      name = "automation-science-pack",
      count = 10
    }, {
      entries = {},
      research = {
        pack_consumption_per_minute = {
          ["automation-science-pack"] = 30
        }
      }
    }, {})

    assert.is_true(math.abs(seconds - 20) < 0.0001)
  end)
end)
