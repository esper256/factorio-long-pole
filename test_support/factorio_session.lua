-- A Factorio-shaped event session so tests can boot the real runtime, fire
-- API events, and read HUD / ledger outcomes without launching the game.
local vanilla = require("test_support.vanilla_prototypes")
local game_state = require("game_state.game_state")
local long_pole_runtime_state = require("runtime_state.long_pole_runtime_state")
local speedrun_attempts = require("runtime_state.speedrun_attempts")
local construction_progress = require("progress_analysis.construction_progress")
local next_split_construction_progress = require("progress_analysis.next_split_construction_progress")
local research_progress = require("progress_analysis.research_progress")
local observed_crafts = require("progress_analysis.observed_crafts")

local M = {}

local event_handlers = {}
local nth_tick_handlers = {}
local on_init_handler
local player
local item_statistics
local fluid_statistics
local nauvis
local player_settings

local function gui_element(parent, specification)
  local child = {
    type = specification.type,
    name = specification.name or "",
    caption = specification.caption,
    sprite = specification.sprite,
    tooltip = specification.tooltip,
    value = specification.value,
    visible = true,
    valid = true,
    style = {},
    direction = specification.direction,
    column_count = specification.column_count
  }
  local named = {}
  local order = {}

  child.add = function(child_specification)
    local grandchild = gui_element(child, child_specification)
    order[#order + 1] = grandchild
    if grandchild.name ~= "" then
      child[grandchild.name] = grandchild
      named[grandchild.name] = true
    end
    return grandchild
  end
  child.clear = function()
    for name in pairs(named) do
      child[name] = nil
      named[name] = nil
    end
    for index = #order, 1, -1 do
      order[index] = nil
    end
  end
  child.destroy = function()
    if parent then
      if child.name ~= "" then
        parent[child.name] = nil
      end
    end
  end

  return child
end

local function install_globals(options)
  options = options or {}
  storage = {}
  defines = {
    events = {
      on_player_created = 1,
      on_player_joined_game = 2,
      on_gui_click = 3,
      on_runtime_mod_setting_changed = 4,
      on_built_entity = 5,
      on_player_mined_entity = 6,
      on_robot_mined_entity = 7,
      on_space_platform_mined_entity = 8,
      on_entity_died = 9,
      script_raised_destroy = 10,
      on_research_finished = 11,
      on_robot_built_entity = 12,
      on_space_platform_built_entity = 13,
      on_player_mined_item = 14
    },
    inventory = {
      item_main = 1
    },
    flow_precision_index = {
      one_minute = 1
    },
    entity_status = {
      working = 1
    }
  }

  prototypes = {
    entity = vanilla.entity(),
    recipe = vanilla.recipe(),
    technology = vanilla.technology(),
    item = vanilla.item(),
    fluid = vanilla.fluid()
  }

  helpers = {
    is_valid_sprite_path = function()
      return false
    end
  }

  item_statistics = {
    input_counts = {},
    output_counts = {},
    produced_rates = {},
    consumed_rates = {},
    get_flow_count = function(query)
      local rates = query.category == "input"
        and item_statistics.produced_rates
        or item_statistics.consumed_rates
      return rates[query.name] or 0
    end
  }

  fluid_statistics = {
    input_counts = {},
    output_counts = {},
    produced_rates = {},
    consumed_rates = {},
    get_flow_count = function(query)
      local rates = query.category == "input"
        and fluid_statistics.produced_rates
        or fluid_statistics.consumed_rates
      return rates[query.name] or 0
    end
  }

  nauvis = {
    name = "nauvis",
    entities = {},
    find_entities_filtered = function(filter)
      local wanted_types
      if type(filter.type) == "table" then
        wanted_types = {}
        for _, type_name in ipairs(filter.type) do
          wanted_types[type_name] = true
        end
      elseif filter.type then
        wanted_types = { [filter.type] = true }
      end
      local found = {}
      for _, entity in ipairs(nauvis.entities) do
        if (not wanted_types or wanted_types[entity.type])
          and (not filter.force or filter.force == entity.force) then
          found[#found + 1] = entity
        end
      end
      return found
    end
  }

  local technologies = vanilla.technology()
  local force = {
    name = "player",
    current_research = nil,
    research_progress = 0,
    technologies = technologies,
    get_item_production_statistics = function()
      return item_statistics
    end,
    get_fluid_production_statistics = function()
      return fluid_statistics
    end
  }

  player_settings = {
    ["long-pole-auto-load-first-plan"] = { value = options.auto_load ~= false },
    ["long-pole-auto-advance-split"] = { value = options.auto_advance == true },
    ["long-pole-put-current-split-in-quickbar"] = { value = options.quickbar == true }
  }

  local left = gui_element(nil, { type = "flow", name = "left" })
  player = {
    index = 1,
    valid = true,
    name = "tester",
    print = function()
    end,
    crafting_queue = options.crafting_queue or {},
    quick_bar_width = 10,
    blueprints = options.blueprints or {
      require("test_data.speedrun_plan_book")
    },
    gui = {
      left = left
    },
    set_quick_bar_slot = function()
    end
  }

  settings = {
    get_player_settings = function()
      return player_settings
    end
  }

  game = {
    tick = 0,
    players = { player },
    get_player = function(index)
      return game.players[index]
    end,
    forces = {
      player = force
    },
    surfaces = { nauvis }
  }

  event_handlers = {}
  nth_tick_handlers = {}
  script = {
    register_metatable = function()
    end,
    on_init = function(handler)
      on_init_handler = handler
    end,
    on_configuration_changed = function()
    end,
    on_event = function(event_id, handler)
      event_handlers[event_id] = handler
    end,
    on_nth_tick = function(nth, handler)
      nth_tick_handlers[nth] = handler
    end
  }
end

local function dispatch(event_id, event)
  event.name = event.name or event_id
  local handler = event_handlers[event_id]
  if handler then
    handler(event)
  end
end

local function add_world_entity(entity)
  entity.valid = true
  entity.force = entity.force or game.forces.player
  entity.surface = entity.surface or { name = "nauvis" }
  nauvis.entities[#nauvis.entities + 1] = entity
  return entity
end

local function entity_type(name)
  local proto = prototypes.entity[name]
  return proto and proto.type or "assembling-machine"
end

local function placement_item(name)
  local proto = prototypes.entity[name]
  local items = proto and proto.items_to_place_this
  if items and items[1] then
    return items[1]
  end
  return { name = name, count = 1 }
end

function M.boot(options)
  install_globals(options)
  local bootstrap = require("runtime.bootstrap")
  bootstrap.install(script)
  return M
end

function M.init()
  if on_init_handler then
    on_init_handler()
  end
  dispatch(defines.events.on_player_created, { player_index = player.index })
  return M
end

function M.tick(seconds)
  seconds = seconds or 1
  for _ = 1, seconds do
    game.tick = game.tick + 60
    local handler = nth_tick_handlers[60]
    if handler then
      handler({ tick = game.tick })
    end
  end
  return M
end

function M.player()
  return player
end

function M.attempt()
  return speedrun_attempts.get(player.index)
end

function M.ledger()
  return long_pole_runtime_state.ledger()
end

function M.hud()
  return player.gui.left.long_pole_speedrun_hud
end

function M.analyze()
  local attempt = M.attempt()
  if not attempt then
    return nil
  end
  local state = M.ledger()
  attempt:ensure_current_split_started(state)
  local view = attempt:hud_view(game.tick)
  local split = attempt:current_split()
  if split then
    local crafts = observed_crafts.snapshot()
    view.construction_progress = construction_progress.for_split(
      split,
      state,
      attempt.split_start_placed_product_counts,
      { observed_crafts = crafts }
    )
    view.research_progress = research_progress.for_split(split, state, game.forces.player)
    local next_split = attempt.plan:split_at(attempt.current_split_index + 1)
    if next_split and #next_split.production_item_names > 0 then
      view.next_split_production_progress = next_split_construction_progress.for_splits(
        split,
        next_split,
        state,
        attempt.split_start_placed_product_counts,
        { observed_crafts = crafts }
      )
    end
  end
  return view
end

function M.build(entity_name, extra)
  extra = extra or {}
  local item = extra.item or placement_item(entity_name)
  local entity = add_world_entity({
    name = entity_name,
    type = extra.type or entity_type(entity_name),
    crafting_speed = extra.crafting_speed or 1,
    get_recipe = extra.get_recipe,
    status = extra.status or (entity_type(entity_name) == "lab" and defines.entity_status.working or nil)
  })
  dispatch(defines.events.on_built_entity, {
    entity = entity,
    consumed_items = extra.consumed_items or {
      get_contents = function()
        return {
          { name = item.name, count = item.count }
        }
      end
    }
  })
  return entity
end

function M.robot_build(entity_name)
  local item = placement_item(entity_name)
  local entity = add_world_entity({
    name = entity_name,
    type = entity_type(entity_name)
  })
  dispatch(defines.events.on_robot_built_entity, {
    entity = entity,
    stack = { name = item.name, count = item.count }
  })
  return entity
end

function M.mine_entity(spec)
  dispatch(defines.events.on_player_mined_entity, {
    entity = {
      name = spec.name,
      type = spec.type,
      amount = spec.amount,
      surface = { name = spec.surface or "nauvis" },
      prototype = prototypes.entity[spec.name]
    },
    buffer = {
      get_contents = function()
        return spec.buffer or {}
      end
    }
  })
end

function M.mine_rock(drops)
  local buffer = {}
  for name, count in pairs(drops) do
    buffer[#buffer + 1] = { name = name, count = count }
  end
  M.mine_entity({
    name = "huge-rock",
    type = "simple-entity",
    buffer = buffer
  })
end

function M.mine_ore(name, count)
  item_statistics.input_counts[name] = (item_statistics.input_counts[name] or 0) + count
  M.mine_entity({
    name = name,
    type = "resource",
    amount = 120,
    buffer = {
      { name = name, count = count }
    }
  })
  dispatch(defines.events.on_player_mined_item, {
    item_stack = { name = name, count = count }
  })
end

function M.produce(counts)
  for name, count in pairs(counts) do
    item_statistics.input_counts[name] = (item_statistics.input_counts[name] or 0) + count
  end
end

function M.consume(counts)
  for name, count in pairs(counts) do
    item_statistics.output_counts[name] = (item_statistics.output_counts[name] or 0) + count
  end
end

function M.set_rate(name, produced_per_minute)
  item_statistics.produced_rates[name] = produced_per_minute
end

function M.begin_research(technology_name, progress)
  local technology = game.forces.player.technologies[technology_name]
  game.forces.player.current_research = technology
  game.forces.player.research_progress = progress or 0
end

function M.finish_research(technology_name)
  local technology = game.forces.player.technologies[technology_name]
  technology.researched = true
  game.forces.player.current_research = nil
  game.forces.player.research_progress = 0
  dispatch(defines.events.on_research_finished, { research = technology })
end

function M.press(input_name)
  dispatch(input_name, { player_index = player.index })
end

function M.click(element_name)
  dispatch(defines.events.on_gui_click, {
    player_index = player.index,
    element = {
      valid = true,
      name = element_name
    }
  })
end

function M.place_current_print()
  local attempt = M.attempt()
  local split = attempt:current_split()
  local state = M.ledger()
  for _, item_name in ipairs(split.placement_item_names) do
    local required = split:placement_item_count(item_name)
    local placed_now = game_state.total_placed_products(state, item_name)
    local at_start = attempt.split_start_placed_product_counts[item_name] or 0
    local already = math.min(required, math.max(0, placed_now - at_start))
    for _ = 1, required - already do
      M.build(item_name)
    end
  end
end

function M.product(name)
  local surface = M.ledger().surfaces.nauvis
  return surface and surface.products[name]
end

return M
