local M = {}

function M.register(script_root, handlers)
  script_root.on_init(handlers.on_init)
  script_root.on_configuration_changed(handlers.on_configuration_changed)
  script_root.on_load(handlers.on_load)
end

return M
