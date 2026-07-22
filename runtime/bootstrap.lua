local event_registry = require("runtime.event_registry")
local tick_driver = require("runtime.tick_driver")

local M = {}

local function on_init()
  tick_driver.on_init()
end

local function on_configuration_changed(_event)
  tick_driver.on_configuration_changed()
end

local function on_load()
  tick_driver.on_load()
end

function M.register(script_root)
  event_registry.register(script_root, {
    on_init = on_init,
    on_configuration_changed = on_configuration_changed,
    on_load = on_load
  })
end

return M
