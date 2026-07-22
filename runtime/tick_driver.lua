local M = {}

function M.on_init()
  storage.long_pole = storage.long_pole or {
    version = 1
  }
end

function M.on_configuration_changed()
  storage.long_pole = storage.long_pole or {
    version = 1
  }
end

function M.on_load()
  -- Intentionally empty. Runtime-only registrations will be added here as
  -- later implementation steps introduce event-driven systems.
end

return M
