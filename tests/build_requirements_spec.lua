local build_requirements = require("build_requirements")

describe("build_requirements", function()
  local original_game
  local original_prototypes

  local function summary_by_key(summary)
    local indexed = {}
    for _, entry in ipairs(summary or {}) do
      indexed[("%s:%s"):format(entry.kind, entry.name)] = entry.count
    end
    return indexed
  end

  before_each(function()
    original_game = rawget(_G, "game")
    original_prototypes = rawget(_G, "prototypes")
    _G.game = nil
    _G.prototypes = nil
  end)

  after_each(function()
    _G.game = original_game
    _G.prototypes = original_prototypes
  end)

  it("merges blueprint place-item counts with extra items", function()
    local split = {
      blueprints = {
        {
          entity_summary = {
            {name = "transport-belt", count = 12},
            {name = "assembling-machine-1", count = 2}
          }
        }
      },
      items = {
        {name = "transport-belt", count = 8},
        {name = "iron-chest", count = 1}
      }
    }

    local summary = build_requirements.summarize_split(split, function(entity_name)
      local mapping = {
        ["transport-belt"] = {
          {kind = "item", name = "transport-belt", count = 1}
        },
        ["assembling-machine-1"] = {
          {kind = "item", name = "assembling-machine-1", count = 1}
        }
      }
      return mapping[entity_name]
    end)

    assert.are.equal("item", summary[1].kind)
    assert.are.equal("transport-belt", summary[1].name)
    assert.are.equal(20, summary[1].count)
    assert.are.equal("assembling-machine-1", summary[2].name)
    assert.are.equal(2, summary[2].count)
    assert.are.equal("iron-chest", summary[3].name)
    assert.are.equal(1, summary[3].count)
  end)

  it("adds selected research science packs into the split summary", function()
    local split = {
      blueprints = {},
      items = {
        {name = "lab", count = 1}
      },
      technologies = {
        {name = "automation"}
      }
    }

    local summary = build_requirements.summarize_split(split, {
      resolve_technology_components = function(technology_name)
        assert.are.equal("automation", technology_name)
        return {
          {kind = "item", name = "automation-science-pack", count = 10}
        }
      end
    })

    assert.same({
      ["item:automation-science-pack"] = 10,
      ["item:lab"] = 1
    }, summary_by_key(summary))
  end)

  it("falls back to entity sprites when no place item mapping exists", function()
    local split = {
      blueprints = {
        {
          entity_summary = {
            {name = "mystery-entity", count = 3}
          }
        }
      },
      items = {}
    }

    local summary = build_requirements.summarize_split(split, function()
      return nil
    end)

    assert.are.equal(1, #summary)
    assert.are.equal("entity", summary[1].kind)
    assert.are.equal("mystery-entity", summary[1].name)
    assert.are.equal(3, summary[1].count)
    assert.are.equal("entity/mystery-entity", summary[1].sprite)
  end)

  it("uses runtime prototypes.entity instead of game.entity_prototypes", function()
    _G.game = setmetatable({}, {
      __index = function(_, key)
        if key == "entity_prototypes" then
          error("legacy prototype lookup should not be used")
        end
      end
    })

    _G.prototypes = {
      entity = {
        ["assembling-machine-1"] = {
          items_to_place_this = {
            {name = "assembling-machine-1", count = 1}
          }
        }
      }
    }

    local resolved = build_requirements.resolve_entity_place_items("assembling-machine-1")

    assert.same({
      {kind = "item", name = "assembling-machine-1", count = 1}
    }, resolved)
  end)

  it("expands a single recipe layer into raw resources", function()
    local split = {
      surface = "nauvis",
      blueprints = {
        {
          entity_summary = {
            {name = "stone-furnace", count = 21}
          }
        }
      },
      items = {}
    }

    local summary = build_requirements.summarize_raw_cost(split, {
      resolve_entity_components = function(entity_name)
        return {
          {kind = "item", name = entity_name, count = 1}
        }
      end,
      resolve_recipe_set = function(kind, name, surface_name)
        assert.are.equal("item", kind)
        assert.are.equal("stone-furnace", name)
        assert.are.equal("nauvis", surface_name)
        return {
          {
            ingredients = {
              {type = "item", name = "stone", amount = 5}
            },
            products = {
              {type = "item", name = "stone-furnace", amount = 1}
            }
          }
        }
      end
    })

    assert.are.equal(1, #summary)
    assert.are.equal("item", summary[1].kind)
    assert.are.equal("stone", summary[1].name)
    assert.are.equal(105, summary[1].count)
  end)

  it("prefers the recipe that yields fewer raw resources on the selected surface", function()
    local split = {
      surface = "gleba",
      blueprints = {},
      items = {
        {name = "nutrients", count = 10}
      }
    }

    local summary = build_requirements.summarize_raw_cost(split, {
      resolve_recipe_set = function(kind, name, surface_name)
        assert.are.equal("item", kind)
        assert.are.equal("gleba", surface_name)
        if name ~= "nutrients" then
          return {}
        end

        return {
          {
            ingredients = {
              {type = "item", name = "yumako", amount = 20}
            },
            products = {
              {type = "item", name = "nutrients", amount = 1}
            }
          },
          {
            ingredients = {
              {type = "item", name = "pentapod-egg", amount = 1}
            },
            products = {
              {type = "item", name = "nutrients", amount = 5}
            }
          }
        }
      end
    })

    assert.are.equal("item", summary[1].kind)
    assert.are.equal("pentapod-egg", summary[1].name)
    assert.are.equal(2, summary[1].count)
  end)

  it("omits Nauvis water from displayed raw costs", function()
    local split = {
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "steam", count = 100}
      }
    }

    local summary = build_requirements.summarize_raw_cost(split, {
      resolve_recipe_set = function(_kind, _name, _surface_name)
        return {
          {
            ingredients = {
              {type = "fluid", name = "water", amount = 100}
            },
            products = {
              {type = "item", name = "steam", amount = 100}
            }
          }
        }
      end
    })

    assert.are.equal(0, #summary)
  end)

  it("recursively expands through multiple crafting layers into raw resources", function()
    local split = {
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "transport-belt", count = 4}
      }
    }

    local summary = build_requirements.summarize_raw_cost(split, {
      resolve_recipe_set = function(_kind, name)
        local recipes = {
          ["transport-belt"] = {
            {
              ingredients = {
                {type = "item", name = "iron-plate", amount = 1},
                {type = "item", name = "iron-gear-wheel", amount = 1}
              },
              products = {
                {type = "item", name = "transport-belt", amount = 2}
              }
            }
          },
          ["iron-gear-wheel"] = {
            {
              ingredients = {
                {type = "item", name = "iron-plate", amount = 2}
              },
              products = {
                {type = "item", name = "iron-gear-wheel", amount = 1}
              }
            }
          },
          ["iron-plate"] = {
            {
              ingredients = {
                {type = "item", name = "iron-ore", amount = 1}
              },
              products = {
                {type = "item", name = "iron-plate", amount = 1}
              }
            }
          }
        }
        return recipes[name] or {}
      end
    })

    assert.same({
      ["item:iron-ore"] = 6
    }, summary_by_key(summary))
  end)

  it("uses product amount and probability when expanding recipe costs", function()
    local split = {
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "processing-unit", count = 2}
      }
    }

    local summary = build_requirements.summarize_raw_cost(split, {
      resolve_recipe_set = function(_kind, name)
        local recipes = {
          ["processing-unit"] = {
            {
              ingredients = {
                {type = "item", name = "advanced-circuit", amount = 2}
              },
              products = {
                {type = "item", name = "processing-unit", amount_min = 1, amount_max = 3, probability = 0.5}
              }
            }
          },
          ["advanced-circuit"] = {
            {
              ingredients = {
                {type = "item", name = "copper-ore", amount = 8}
              },
              products = {
                {type = "item", name = "advanced-circuit", amount = 2}
              }
            }
          }
        }
        return recipes[name] or {}
      end
    })

    assert.same({
      ["item:copper-ore"] = 16
    }, summary_by_key(summary))
  end)

  it("expands research science packs into raw resources", function()
    local split = {
      surface = "nauvis",
      blueprints = {},
      items = {},
      technologies = {
        {name = "automation"}
      }
    }

    local summary = build_requirements.summarize_raw_cost(split, {
      resolve_technology_components = function(technology_name)
        assert.are.equal("automation", technology_name)
        return {
          {kind = "item", name = "automation-science-pack", count = 10}
        }
      end,
      resolve_recipe_set = function(_kind, name)
        if name == "automation-science-pack" then
          return {
            {
              ingredients = {
                {type = "item", name = "copper-plate", amount = 1},
                {type = "item", name = "iron-gear-wheel", amount = 1}
              },
              products = {
                {type = "item", name = "automation-science-pack", amount = 1}
              }
            }
          }
        end

        if name == "iron-gear-wheel" then
          return {
            {
              ingredients = {
                {type = "item", name = "iron-plate", amount = 2}
              },
              products = {
                {type = "item", name = "iron-gear-wheel", amount = 1}
              }
            }
          }
        end

        if name == "iron-plate" then
          return {
            {
              ingredients = {
                {type = "item", name = "iron-ore", amount = 1}
              },
              products = {
                {type = "item", name = "iron-plate", amount = 1}
              }
            }
          }
        end

        if name == "copper-plate" then
          return {
            {
              ingredients = {
                {type = "item", name = "copper-ore", amount = 1}
              },
              products = {
                {type = "item", name = "copper-plate", amount = 1}
              }
            }
          }
        end

        return {}
      end
    })

    assert.same({
      ["item:copper-ore"] = 10,
      ["item:iron-ore"] = 20
    }, summary_by_key(summary))
  end)

  it("returns an error when no recipe exists", function()
    local split = {
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "mystery-component", count = 3}
      }
    }

    local summary, error_message = build_requirements.summarize_raw_cost(split, {
      resolve_recipe_set = function()
        return {}
      end
    })

    assert.same({}, summary_by_key(summary))
    assert.is_truthy(error_message)
    assert.is_truthy(error_message:match("item:mystery%-component"))
  end)

  it("returns an error when recipe expansion hits a cycle", function()
    local split = {
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "loop-a", count = 2}
      }
    }

    local summary, error_message = build_requirements.summarize_raw_cost(split, {
      resolve_recipe_set = function(_kind, name)
        local recipes = {
          ["loop-a"] = {
            {
              ingredients = {
                {type = "item", name = "loop-b", amount = 1}
              },
              products = {
                {type = "item", name = "loop-a", amount = 1}
              }
            }
          },
          ["loop-b"] = {
            {
              ingredients = {
                {type = "item", name = "loop-a", amount = 1}
              },
              products = {
                {type = "item", name = "loop-b", amount = 1}
              }
            }
          }
        }
        return recipes[name] or {}
      end
    })

    assert.same({}, summary_by_key(summary))
    assert.is_truthy(error_message)
    assert.is_truthy(error_message:match("recipe cycle"))
  end)

  it("filters prototype recipes by the selected surface conditions", function()
    _G.prototypes = {
      recipe = {
        ["steam-on-nauvis"] = {
          ingredients = {
            {type = "item", name = "coal", amount = 1}
          },
          products = {
            {type = "item", name = "steam-core", amount = 1}
          },
          surface_conditions = {
            {property = "pressure", min = 900, max = 1100}
          }
        },
        ["steam-on-vulcanus"] = {
          ingredients = {
            {type = "item", name = "calcite", amount = 2}
          },
          products = {
            {type = "item", name = "steam-core", amount = 1}
          },
          surface_conditions = {
            {property = "pressure", min = 3500, max = 4500}
          }
        }
      },
      surface = {
        nauvis = {
          surface_properties = {
            pressure = 1000
          }
        },
        vulcanus = {
          surface_properties = {
            pressure = 4000
          }
        }
      }
    }

    local nauvis_summary = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "steam-core", count = 2}
      }
    })

    local vulcanus_summary = build_requirements.summarize_raw_cost({
      surface = "vulcanus",
      blueprints = {},
      items = {
        {name = "steam-core", count = 2}
      }
    })

    assert.same({
      ["item:coal"] = 2
    }, summary_by_key(nauvis_summary))
    assert.same({
      ["item:calcite"] = 4
    }, summary_by_key(vulcanus_summary))
  end)

  it("filters prototype recipes by configurable recipe categories", function()
    _G.prototypes = {
      recipe = {
        ["iron-plate-on-nauvis"] = {
          category = "smelting",
          ingredients = {
            {type = "item", name = "iron-ore", amount = 1}
          },
          products = {
            {type = "item", name = "iron-plate", amount = 1}
          }
        },
        ["gear-recycling"] = {
          category = "recycling",
          ingredients = {
            {type = "item", name = "scrap", amount = 1}
          },
          products = {
            {type = "item", name = "iron-gear-wheel", amount = 1}
          }
        },
        ["gear-crafting"] = {
          category = "crafting",
          ingredients = {
            {type = "item", name = "iron-plate", amount = 2}
          },
          products = {
            {type = "item", name = "iron-gear-wheel", amount = 1}
          }
        }
      }
    }

    local summary = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "iron-gear-wheel", count = 3}
      }
    })

    assert.same({
      ["item:iron-ore"] = 6
    }, summary_by_key(summary))
  end)

  it("filters recycling-or-hand-crafting recipes off non-fulgora surfaces", function()
    _G.prototypes = {
      recipe = {
        ["automation-science-pack-recycling"] = {
          category = "recycling-or-hand-crafting",
          ingredients = {
            {type = "item", name = "scrap", amount = 1}
          },
          products = {
            {type = "item", name = "automation-science-pack", amount = 1}
          }
        },
        ["automation-science-pack-crafting"] = {
          category = "crafting",
          ingredients = {
            {type = "item", name = "copper-plate", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 1}
          },
          products = {
            {type = "item", name = "automation-science-pack", amount = 1}
          }
        },
        ["iron-gear-wheel-crafting"] = {
          category = "crafting",
          ingredients = {
            {type = "item", name = "iron-plate", amount = 2}
          },
          products = {
            {type = "item", name = "iron-gear-wheel", amount = 1}
          }
        },
        ["copper-plate-smelting"] = {
          category = "smelting",
          ingredients = {
            {type = "item", name = "copper-ore", amount = 1}
          },
          products = {
            {type = "item", name = "copper-plate", amount = 1}
          }
        },
        ["iron-plate-smelting"] = {
          category = "smelting",
          ingredients = {
            {type = "item", name = "iron-ore", amount = 1}
          },
          products = {
            {type = "item", name = "iron-plate", amount = 1}
          }
        }
      }
    }

    local summary = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "automation-science-pack", count = 2}
      }
    })

    assert.same({
      ["item:copper-ore"] = 2,
      ["item:iron-ore"] = 4
    }, summary_by_key(summary))
  end)

  it("rejects categories that are not explicitly allowed on the selected surface", function()
    _G.prototypes = {
      recipe = {
        ["iron-plate-crushing"] = {
          category = "crushing",
          ingredients = {
            {type = "item", name = "asteroid-chunk", amount = 1}
          },
          products = {
            {type = "item", name = "iron-plate", amount = 1}
          }
        }
      }
    }

    local summary, error_message = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "iron-plate", count = 1}
      }
    })

    assert.same({}, summary_by_key(summary))
    assert.is_truthy(error_message)
    assert.is_truthy(error_message:match("item:iron%-plate"))
  end)

  it("allows chemistry hybrid categories used by standard Nauvis chemical recipes", function()
    _G.prototypes = {
      recipe = {
        ["plastic-bar"] = {
          category = "chemistry-or-cryogenics",
          ingredients = {
            {type = "item", name = "coal", amount = 1},
            {type = "fluid", name = "petroleum-gas", amount = 20}
          },
          products = {
            {type = "item", name = "plastic-bar", amount = 2}
          }
        },
        ["basic-oil-processing"] = {
          category = "oil-processing",
          ingredients = {
            {type = "fluid", name = "crude-oil", amount = 100}
          },
          products = {
            {type = "fluid", name = "petroleum-gas", amount = 45}
          }
        }
      }
    }

    local summary, error_message = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "plastic-bar", count = 4}
      }
    })
    local indexed = summary_by_key(summary)

    assert.is_nil(error_message)
    assert.are.equal(2, indexed["item:coal"])
    assert.is_true(math.abs(indexed["fluid:crude-oil"] - 88.88888888888889) < 0.0000001)
  end)

  it("allows metallurgy hybrid categories used by standard Nauvis assembler recipes", function()
    _G.prototypes = {
      recipe = {
        ["transport-belt"] = {
          category = "metallurgy-or-assembling",
          ingredients = {
            {type = "item", name = "iron-plate", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 1}
          },
          products = {
            {type = "item", name = "transport-belt", amount = 2}
          }
        },
        ["iron-gear-wheel"] = {
          category = "metallurgy-or-assembling",
          ingredients = {
            {type = "item", name = "iron-plate", amount = 2}
          },
          products = {
            {type = "item", name = "iron-gear-wheel", amount = 1}
          }
        },
        ["iron-plate-smelting"] = {
          category = "smelting",
          ingredients = {
            {type = "item", name = "iron-ore", amount = 1}
          },
          products = {
            {type = "item", name = "iron-plate", amount = 1}
          }
        }
      }
    }

    local summary, error_message = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "transport-belt", count = 4}
      }
    })

    assert.is_nil(error_message)
    assert.same({
      ["item:iron-ore"] = 6
    }, summary_by_key(summary))
  end)

  it("accepts recipes when an allowed category appears in additional_categories", function()
    _G.prototypes = {
      recipe = {
        ["transport-belt"] = {
          category = "crushing",
          additional_categories = {"metallurgy-or-assembling"},
          ingredients = {
            {type = "item", name = "iron-plate", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 1}
          },
          products = {
            {type = "item", name = "transport-belt", amount = 2}
          }
        },
        ["iron-gear-wheel"] = {
          category = "crafting",
          ingredients = {
            {type = "item", name = "iron-plate", amount = 2}
          },
          products = {
            {type = "item", name = "iron-gear-wheel", amount = 1}
          }
        },
        ["iron-plate-smelting"] = {
          category = "smelting",
          ingredients = {
            {type = "item", name = "iron-ore", amount = 1}
          },
          products = {
            {type = "item", name = "iron-plate", amount = 1}
          }
        }
      }
    }

    local summary, error_message = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "transport-belt", count = 4}
      }
    })

    assert.is_nil(error_message)
    assert.same({
      ["item:iron-ore"] = 6
    }, summary_by_key(summary))
  end)

  it("allows pressing recipes used by normal Nauvis item production", function()
    _G.prototypes = {
      recipe = {
        ["transport-belt"] = {
          category = "pressing",
          ingredients = {
            {type = "item", name = "iron-plate", amount = 1},
            {type = "item", name = "iron-gear-wheel", amount = 1}
          },
          products = {
            {type = "item", name = "transport-belt", amount = 2}
          }
        },
        ["iron-gear-wheel"] = {
          category = "crafting",
          ingredients = {
            {type = "item", name = "iron-plate", amount = 2}
          },
          products = {
            {type = "item", name = "iron-gear-wheel", amount = 1}
          }
        },
        ["iron-plate-smelting"] = {
          category = "smelting",
          ingredients = {
            {type = "item", name = "iron-ore", amount = 1}
          },
          products = {
            {type = "item", name = "iron-plate", amount = 1}
          }
        }
      }
    }

    local summary, error_message = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "transport-belt", count = 4}
      }
    })

    assert.is_nil(error_message)
    assert.same({
      ["item:iron-ore"] = 6
    }, summary_by_key(summary))
  end)

  it("treats the current Gleba egg item as a raw resource", function()
    local split = {
      surface = "gleba",
      blueprints = {},
      items = {
        {name = "bioflux", count = 6}
      }
    }

    local summary = build_requirements.summarize_raw_cost(split, {
      resolve_recipe_set = function(_kind, name)
        if name == "bioflux" then
          return {
            {
              ingredients = {
                {type = "item", name = "pentapod-egg", amount = 3}
              },
              products = {
                {type = "item", name = "bioflux", amount = 3}
              }
            }
          }
        end
        return {}
      end
    })

    assert.same({
      ["item:pentapod-egg"] = 6
    }, summary_by_key(summary))
  end)

  it("ignores explicitly blocked prototypes when summarizing raw cost", function()
    local summary, error_message = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "loader", count = 2},
        {name = "iron-ore", count = 5}
      }
    }, {
      resolve_recipe_set = function()
        return {}
      end
    })

    assert.is_nil(error_message)
    assert.same({
      ["item:iron-ore"] = 5
    }, summary_by_key(summary))
  end)

  it("returns an error when raw cost receives an unresolved entity marker", function()
    local summary, error_message = build_requirements.summarize_raw_cost({
      surface = "nauvis",
      blueprints = {
        {
          entity_summary = {
            {name = "mystery-marker", count = 1}
          }
        }
      },
      items = {}
    }, {
      resolve_entity_components = function()
        return nil
      end,
      resolve_recipe_set = function()
        return {}
      end
    })

    assert.same({}, summary_by_key(summary))
    assert.is_truthy(error_message)
    assert.is_truthy(error_message:match("entity:mystery%-marker"))
  end)

  it("computes remaining intermediates after reserving completed split outputs first", function()
    local summary = build_requirements.summarize_missing_requirements({
      surface = "nauvis",
      blueprints = {
        {
          entity_summary = {
            {name = "transport-belt", count = 6}
          }
        }
      },
      items = {}
    }, {
      entries = {
        {
          item_name = "transport-belt",
          loose_stock = 2,
          current_split_claim = 2
        },
        {
          item_name = "iron-plate",
          loose_stock = 1,
          current_split_claim = 0
        }
      }
    }, {
      resolve_entity_components = function(entity_name)
        return {
          {kind = "item", name = entity_name, count = 1}
        }
      end,
      resolve_recipe_set = function(_kind, name)
        local recipes = {
          ["transport-belt"] = {
            {
              ingredients = {
                {type = "item", name = "iron-plate", amount = 1},
                {type = "item", name = "iron-gear-wheel", amount = 1}
              },
              products = {
                {type = "item", name = "transport-belt", amount = 2}
              }
            }
          },
          ["iron-gear-wheel"] = {
            {
              ingredients = {
                {type = "item", name = "iron-plate", amount = 2}
              },
              products = {
                {type = "item", name = "iron-gear-wheel", amount = 1}
              }
            }
          }
        }
        return recipes[name] or {}
      end
    })
    local indexed = {}
    for _, entry in ipairs(summary) do
      indexed[("%s:%s"):format(entry.kind, entry.name)] = entry
    end

    assert.are.equal(2, indexed["item:transport-belt"].count)
    assert.are.equal(6, indexed["item:transport-belt"].required_count)
    assert.are.equal(4, indexed["item:transport-belt"].fulfilled_count)
    assert.is_true(math.abs(indexed["item:transport-belt"].progress - (4 / 6)) < 0.0000001)

    assert.are.equal(1, indexed["item:iron-gear-wheel"].count)
    assert.are.equal(1, indexed["item:iron-gear-wheel"].required_count)
    assert.are.equal(0, indexed["item:iron-gear-wheel"].fulfilled_count)

    assert.are.equal(2, indexed["item:iron-plate"].count)
    assert.are.equal(3, indexed["item:iron-plate"].required_count)
    assert.are.equal(1, indexed["item:iron-plate"].fulfilled_count)
  end)

  it("keeps placed split claims from satisfying loose-only item requirements", function()
    local summary = build_requirements.summarize_missing_requirements({
      surface = "nauvis",
      blueprints = {
        {
          entity_summary = {
            {name = "transport-belt", count = 1}
          }
        }
      },
      items = {
        {name = "transport-belt", count = 1}
      }
    }, {
      entries = {
        {
          item_name = "transport-belt",
          loose_stock = 0,
          current_split_claim = 1
        }
      }
    }, {
      resolve_entity_components = function(entity_name)
        return {
          {kind = "item", name = entity_name, count = 1}
        }
      end,
      resolve_recipe_set = function()
        return {}
      end
    })

    assert.are.equal(1, #summary)
    assert.are.equal("transport-belt", summary[1].name)
    assert.are.equal(1, summary[1].count)
    assert.are.equal(2, summary[1].required_count)
    assert.are.equal(1, summary[1].fulfilled_count)
  end)

  it("uses loose intermediates to avoid blaming already-available components", function()
    local summary = build_requirements.summarize_missing_requirements({
      surface = "nauvis",
      blueprints = {},
      items = {
        {name = "transport-belt", count = 4}
      }
    }, {
      entries = {
        {
          item_name = "transport-belt",
          loose_stock = 2,
          current_split_claim = 0
        },
        {
          item_name = "iron-gear-wheel",
          loose_stock = 1,
          current_split_claim = 0
        },
        {
          item_name = "iron-plate",
          loose_stock = 1,
          current_split_claim = 0
        }
      }
    }, {
      resolve_recipe_set = function(_kind, name)
        local recipes = {
          ["transport-belt"] = {
            {
              ingredients = {
                {type = "item", name = "iron-plate", amount = 1},
                {type = "item", name = "iron-gear-wheel", amount = 1}
              },
              products = {
                {type = "item", name = "transport-belt", amount = 2}
              }
            }
          },
          ["iron-gear-wheel"] = {
            {
              ingredients = {
                {type = "item", name = "iron-plate", amount = 2}
              },
              products = {
                {type = "item", name = "iron-gear-wheel", amount = 1}
              }
            }
          }
        }
        return recipes[name] or {}
      end
    })

    assert.are.equal(1, #summary)
    assert.are.equal("transport-belt", summary[1].name)
    assert.are.equal(2, summary[1].count)
    assert.are.equal(4, summary[1].required_count)
    assert.are.equal(2, summary[1].fulfilled_count)
  end)

  it("can summarize direct root-item progress without expanding into intermediates", function()
    local summary = build_requirements.summarize_direct_requirement_progress({
      surface = "nauvis",
      blueprints = {
        {
          entity_summary = {
            {name = "transport-belt", count = 4}
          }
        }
      },
      items = {
        {name = "iron-chest", count = 2}
      },
      technologies = {
        {name = "automation"}
      }
    }, {
      entries = {
        {
          item_name = "transport-belt",
          loose_stock = 2,
          current_split_claim = 1
        },
        {
          item_name = "iron-chest",
          loose_stock = 1,
          current_split_claim = 0
        }
      }
    }, {
      include_technologies = false,
      resolve_entity_components = function(entity_name)
        return {
          {kind = "item", name = entity_name, count = 1}
        }
      end
    })
    local indexed = {}
    for _, entry in ipairs(summary) do
      indexed[("%s:%s"):format(entry.kind, entry.name)] = entry
    end

    assert.are.equal(1, indexed["item:transport-belt"].count)
    assert.are.equal(4, indexed["item:transport-belt"].required_count)
    assert.are.equal(3, indexed["item:transport-belt"].fulfilled_count)
    assert.are.equal(1, indexed["item:iron-chest"].count)
    assert.are.equal(2, indexed["item:iron-chest"].required_count)
    assert.are.equal(1, indexed["item:iron-chest"].fulfilled_count)
    assert.is_nil(indexed["item:automation-science-pack"])
  end)

  it("supports placed-only direct progress for current blueprint completion", function()
    local summary = build_requirements.summarize_direct_requirement_progress({
      surface = "nauvis",
      blueprints = {
        {
          entity_summary = {
            {name = "transport-belt", count = 4}
          }
        }
      }
    }, {
      entries = {
        {
          item_name = "transport-belt",
          loose_stock = 99,
          current_split_claim = 1
        }
      }
    }, {
      include_items = false,
      include_technologies = false,
      blueprint_satisfaction_mode = "placed_only",
      resolve_entity_components = function(entity_name)
        return {
          {kind = "item", name = entity_name, count = 1}
        }
      end
    })

    assert.are.equal(1, #summary)
    assert.are.equal("transport-belt", summary[1].name)
    assert.are.equal(3, summary[1].count)
    assert.are.equal(4, summary[1].required_count)
    assert.are.equal(1, summary[1].fulfilled_count)
  end)
end)
