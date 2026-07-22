-- Mutable state for one attempt to run an immutable speedrun plan.
local game_state = require("game_state.game_state")

local M = {}

local AttemptMethods = {}
local AttemptMetatable = {
  __index = AttemptMethods
}

function M.new(plan, library_book_index, state)
  local attempt = setmetatable({
    plan = plan,
    library_book_index = library_book_index,
    current_split_index = 1
  }, AttemptMetatable)
  if state then
    attempt:begin_current_split(state)
  end
  return attempt
end

function M.register_metatable(script_root)
  script_root.register_metatable("long-pole-speedrun-attempt", AttemptMetatable)
end

function AttemptMethods:current_split()
  return self.plan:split_at(self.current_split_index)
end

function AttemptMethods:begin_current_split(state)
  local current_split = self:current_split()
  self.split_start_placed_product_counts = current_split
    and game_state.placed_product_count_snapshot(state, current_split.placement_item_names)
    or nil
end

function AttemptMethods:ensure_current_split_started(state)
  if self.split_start_placed_product_counts == nil and self:current_split() then
    self:begin_current_split(state)
  end
end

function AttemptMethods:mark_current_split_done(finished_tick, state)
  local current_split = self.plan:split_at(self.current_split_index)
  if not current_split then
    return
  end

  self.previous_split_index = self.current_split_index
  self.previous_split_finished_tick = finished_tick
  self.current_split_index = self.current_split_index + 1
  if state then
    self:begin_current_split(state)
  else
    self.split_start_placed_product_counts = nil
  end
end

function AttemptMethods:hud_view(game_tick)
  local current_split = self.plan:split_at(self.current_split_index)
  local previous_split = self.previous_split_index
    and self.plan:split_at(self.previous_split_index)
  local next_split = current_split and self.plan:split_at(self.current_split_index + 1)

  return {
    plan_label = self.plan.label,
    previous_split_label = previous_split and previous_split.label or nil,
    previous_split_finished_tick = self.previous_split_finished_tick,
    current_split_label = current_split and current_split.label or "Plan complete",
    next_split_label = next_split and next_split.label or nil,
    game_tick = game_tick,
    library_book_index = self.library_book_index
  }
end

return M
