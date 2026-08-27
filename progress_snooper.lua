local hand_crafting_snooper = require("progress_snoopers.hand_crafting_snooper")
local player_mined_entity_snooper = require("progress_snoopers.player_mined_entity_snooper")
local player_built_entity_snooper = require("progress_snoopers.player_built_entity_snooper")
local production_statistics_snooper = require("progress_snoopers.production_statistics_snooper")
local entity_lifetime_snooper = require("progress_snoopers.entity_lifetime_snooper")
local research_snooper = require("progress_snoopers.research_snooper")

local M = {}

local SNOOPERS = {
  hand_crafting_snooper,
  player_mined_entity_snooper,
  player_built_entity_snooper,
  production_statistics_snooper,
  entity_lifetime_snooper,
  research_snooper
}

local function ensure_registry(state)
  state.progress_snooper = state.progress_snooper or {}
  state.progress_snooper.enabled_snoopers = state.progress_snooper.enabled_snoopers or {}
  state.progress_snooper.handlers_by_event_name = state.progress_snooper.handlers_by_event_name or {}
  return state.progress_snooper
end

local function register_handler(registry, event_name, snooper_id, handler)
  if not (event_name and handler) then
    return
  end

  local handlers = registry.handlers_by_event_name[event_name]
  if not handlers then
    handlers = {}
    registry.handlers_by_event_name[event_name] = handlers
  end

  handlers[#handlers + 1] = {
    snooper_id = snooper_id,
    handler = handler
  }
end

local function resolve_subscription_handler(snooper, subscription)
  if type(subscription) == "function" then
    return function(state, event)
      return subscription(snooper, state, event)
    end
  end

  if type(subscription) == "string" and type(snooper[subscription]) == "function" then
    return function(state, event)
      return snooper[subscription](state, event)
    end
  end

  return nil
end

local function register_snooper_subscriptions(registry, snooper)
  for event_name, subscription in pairs(snooper.subscriptions or {}) do
    local handler = resolve_subscription_handler(snooper, subscription)
    register_handler(registry, event_name, snooper.id, handler)
  end
end

local function collect_subscribed_event_names()
  local event_name_set = {}

  for _, snooper in ipairs(SNOOPERS) do
    for event_name in pairs(snooper.subscriptions or {}) do
      event_name_set[event_name] = true
    end
  end

  local event_names = {}
  for event_name in pairs(event_name_set) do
    event_names[#event_names + 1] = event_name
  end
  table.sort(event_names)
  return event_names
end

function M.init(state)
  local registry = ensure_registry(state)
  registry.handlers_by_event_name = {}

  for _, snooper in ipairs(SNOOPERS) do
    if snooper.id then
      if registry.enabled_snoopers[snooper.id] == nil then
        registry.enabled_snoopers[snooper.id] = true
      end
    end
    if snooper.init then
      snooper.init(state)
    end
    register_snooper_subscriptions(registry, snooper)
  end

  return registry
end

function M.dispatch(state, event_name, event)
  local registry = ensure_registry(state)
  local handlers = registry.handlers_by_event_name[event_name] or {}
  local handled = false

  for _, registered in ipairs(handlers) do
    local enabled = registered.snooper_id == nil or registry.enabled_snoopers[registered.snooper_id] ~= false
    if enabled and registered.handler(state, event) then
      handled = true
    end
  end

  return handled
end

function M.subscribed_event_names()
  return collect_subscribed_event_names()
end

function M.poll(state, runtime)
  local registry = ensure_registry(state)
  local handled = false

  for _, snooper in ipairs(SNOOPERS) do
    if registry.enabled_snoopers[snooper.id] ~= false and snooper.poll then
      handled = snooper.poll(state, runtime) or handled
    end
  end

  return handled
end

return M
