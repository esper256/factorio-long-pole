-- The gameplay HUD creates a compact panel, updates captions in place, and
-- disappears completely when there is no active plan.
local function element(parent, specification)
  local child = {
    name = specification.name or "",
    caption = specification.caption,
    sprite = specification.sprite,
    tooltip = specification.tooltip,
    value = specification.value,
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
  plan_label = "Any% practice",
  current_split_label = "Burner phase",
  next_split_label = "Automation",
  game_tick = 3660,
  construction_progress = {
    total = 10,
    done = 4,
    pending = 3,
    tooltip = "Construction: 4 placed · 3 ready to place · 3 remaining"
  },
  research_progress = {
    total = 20,
    done = 5,
    pending = 10,
    tooltip = "Research: 5 complete · 10 science ready · 5 remaining"
  }
})

local hud_element = left.long_pole_speedrun_hud
local header = hud_element.speedrun_header
assert(hud_element ~= nil)
assert(header.active_speedrun_name.caption == "Any% practice")
assert(hud_element.current_split.caption == "Burner phase  0:01:01")
assert(hud_element.long_pole_advance_split.caption == "Automation")
assert(hud_element.previous_split.visible == false)
assert(header.long_pole_next_plan.sprite == "utility/right_arrow")
assert(hud_element.construction_progress.done.style.width == 128)
assert(hud_element.construction_progress.pending.style.width == 96)
assert(hud_element.construction_progress.not_started.style.width == 96)
assert(hud_element.construction_progress.done.style.bar_width == 6)
assert(hud_element.construction_progress.tooltip == "Construction: 4 placed · 3 ready to place · 3 remaining")
assert(hud_element.research_progress.done.style.width == 80)
assert(hud_element.research_progress.pending.style.width == 160)
assert(hud_element.research_progress.not_started.style.width == 80)
assert(hud_element.research_progress.tooltip == "Research: 5 complete · 10 science ready · 5 remaining")

hud.refresh(player, {
  plan_label = "Any% practice",
  previous_split_label = "Burner phase",
  previous_split_finished_tick = 3600,
  current_split_label = "Automation",
  game_tick = 3720
})

assert(header.active_speedrun_name.caption == "Any% practice")
assert(hud_element.previous_split.visible == true)
assert(hud_element.previous_split.caption == "Burner phase  0:01:00")
assert(hud_element.current_split.caption == "Automation  0:01:02")
assert(hud_element.long_pole_advance_split.visible == false)
assert(hud_element.long_pole_advance_split.caption == "")

hud.refresh(player, nil)
assert(left.long_pole_speedrun_hud ~= nil)
assert(header.active_speedrun_name.caption == "No active speedrun")
assert(hud_element.previous_split.visible == false)
assert(hud_element.current_split.visible == false)
assert(hud_element.long_pole_advance_split.visible == false)
assert(header.long_pole_next_plan.sprite == "utility/right_arrow")
