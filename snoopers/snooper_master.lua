-- Selects the active Factorio-event snoopers and owns their event dispatch.
--
-- Set an entry to false to retain its implementation while disabling it. More
-- than one enabled snooper may observe an event; that is intentional only when
-- their accounting responsibilities do not overlap.
local configured_snoopers = {
  {
    name = "player_mined_item",
    -- Entity-specific mining and production statistics now own item accounting.
    -- Retain this alternative until we deliberately cover tile mining.
    enabled = false,
    module = require("snoopers.player_mined_item")
  },
  {
    name = "starting_inventory",
    enabled = true,
    module = require("snoopers.starting_inventory")
  },
  {
    name = "player_mined_entity",
    enabled = true,
    module = require("snoopers.player_mined_entity")
  },
  {
    name = "player_built_entity",
    enabled = true,
    module = require("snoopers.player_built_entity")
  },
  {
    name = "robot_built_entity",
    enabled = true,
    module = require("snoopers.robot_built_entity")
  },
  {
    name = "production_statistics",
    enabled = true,
    module = require("snoopers.production_statistics")
  },
  {
    name = "research",
    enabled = true,
    module = require("snoopers.research")
  }
}

local handlers_by_event_id = {}
local init_handlers = {}
local second_tick_handlers = {}

local function append_handler(event_id, handler)
  local handlers = handlers_by_event_id[event_id]
  if handlers == nil then
    handlers = {}
    handlers_by_event_id[event_id] = handlers
  end
  handlers[#handlers + 1] = handler
end

for _, snooper in ipairs(configured_snoopers) do
  if snooper.enabled then
    if snooper.module.on_init then
      init_handlers[#init_handlers + 1] = snooper.module.on_init
    end

    if snooper.module.on_second_tick then
      second_tick_handlers[#second_tick_handlers + 1] = snooper.module.on_second_tick
    end

    if snooper.module.event_names then
      for _, event_name in ipairs(snooper.module.event_names) do
        append_handler(defines.events[event_name], snooper.module.on_event)
      end
    end
  end
end

local function dispatch(event)
  local handlers = handlers_by_event_id[event.name]
  if handlers == nil then
    return
  end

  for _, handler in ipairs(handlers) do
    handler(event)
  end
end

local M = {}

function M.on_init()
  for _, handler in ipairs(init_handlers) do
    handler()
  end
end

function M.on_second_tick(event)
  for _, handler in ipairs(second_tick_handlers) do
    handler(event)
  end
end

function M.install(script_root)
  for event_id in pairs(handlers_by_event_id) do
    script_root.on_event(event_id, dispatch)
  end
end

return M
