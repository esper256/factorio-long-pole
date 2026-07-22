-- The gameplay HUD creates a compact panel, updates captions in place, and
-- disappears completely when there is no active plan.
local function element(parent, specification)
  local child = {
    name = specification.name or "",
    caption = specification.caption,
    tooltip = specification.tooltip,
    visible = true,
    style = {}
  }

  child.add = function(child_specification)
    local grandchild = element(child, child_specification)
    child[grandchild.name] = grandchild
    return grandchild
  end
  child.destroy = function()
    parent[child.name] = nil
  end

  return child
end

local left = {}
left.add = function(specification)
  local child = element(left, specification)
  left[child.name] = child
  return child
end

local player = {
  valid = true,
  gui = {
    left = left
  }
}

local hud = require("hud.speedrun_hud")
hud.refresh(player, {
  current_split_label = "Burner phase",
  next_split_label = "Automation",
  game_tick = 3660
})

local frame = left.long_pole_speedrun_hud
assert(frame ~= nil)
assert(frame.current_split.caption == "Current: Burner phase  0:01:01")
assert(frame.next_split.caption == "Next: Automation")
assert(frame.previous_split.visible == false)

hud.refresh(player, {
  previous_split_label = "Burner phase",
  previous_split_finished_tick = 3600,
  current_split_label = "Automation",
  game_tick = 3720
})

assert(frame.previous_split.visible == true)
assert(frame.previous_split.caption == "Previous: Burner phase  0:01:00")
assert(frame.current_split.caption == "Current: Automation  0:01:02")
assert(frame.next_split.caption == "Next: —")

hud.refresh(player, nil)
assert(left.long_pole_speedrun_hud == nil)
