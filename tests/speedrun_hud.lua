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
    style = {},
    child_names = {}
  }

  child.add = function(child_specification)
    local grandchild = element(child, child_specification)
    child[grandchild.name] = grandchild
    child.child_names[grandchild.name] = true
    return grandchild
  end
  child.clear = function()
    for name in pairs(child.child_names) do
      child[name] = nil
    end
    child.child_names = {}
  end
  child.destroy = function()
    parent[child.name] = nil
    if parent.child_names then
      parent.child_names[child.name] = nil
    end
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
    tooltip = "Construction: 4 placed · 3 ready to place · 3 remaining",
    unfinished_items = {
      { item_name = "stone-furnace", count = 3 }
    }
  },
  research_progress = {
    total = 20,
    done = 5,
    pending = 0,
    tooltip = "Research: 5 consumed in labs · 15 remaining · 2 labs working",
    unfinished_items = {
      { item_name = "automation-science-pack", count = 15 }
    }
  },
  next_split_production_progress = {
    total = 10,
    done = 0,
    pending = 3,
    tooltip = "Next production: 3 ready · 7 remaining",
    unfinished_items = {
      { item_name = "iron-gear-wheel", count = 7, eta_ticks = 120 }
    }
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
assert(header.long_pole_next_plan.style.width == 16)
assert(hud_element.construction_progress.indicator_icon.sprite == "item/blueprint")
assert(hud_element.research_progress.indicator_icon.sprite == "utility/technology_white")
assert(hud_element.extra_item_progress == nil)
assert(hud_element.construction_progress.segments.done.style.width == 72)
assert(hud_element.construction_progress.segments.pending.style.width == 54)
assert(hud_element.construction_progress.segments.not_started.style.width == 54)
assert(hud_element.construction_progress.tooltip == "Construction: 4 placed · 3 ready to place · 3 remaining")
assert(hud_element.construction_shortfalls.entry_1.item_icon.sprite == "item/stone-furnace")
assert(hud_element.construction_shortfalls.entry_1.quantity.caption == "3")
assert(hud_element.research_progress.tooltip == "Research: 5 consumed in labs · 15 remaining · 2 labs working")
assert(hud_element.research_shortfalls.entry_1.item_icon.sprite == "item/automation-science-pack")
assert(hud_element.next_split_production_progress.tooltip == "Next production: 3 ready · 7 remaining")
assert(hud_element.next_split_production_shortfalls.entry_1.item_icon.sprite == "item/iron-gear-wheel")
assert(hud_element.next_split_production_shortfalls.entry_1.quantity.caption == "7")

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
assert(hud_element.construction_shortfalls.visible == false)
assert(hud_element.research_shortfalls.visible == false)
assert(hud_element.next_split_production_progress.visible == false)
assert(hud_element.next_split_production_shortfalls.visible == false)

hud.refresh(player, nil)
assert(left.long_pole_speedrun_hud ~= nil)
assert(header.active_speedrun_name.caption == "No active speedrun")
assert(hud_element.previous_split.visible == false)
assert(hud_element.current_split.visible == false)
assert(hud_element.long_pole_advance_split.visible == false)
assert(header.long_pole_next_plan.sprite == "utility/right_arrow")
