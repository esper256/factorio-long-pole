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
    pending = 10,
    tooltip = "Research: 5 complete · 10 science ready · 5 remaining",
    unfinished_items = {
      { item_name = "automation-science-pack", count = 5 }
    }
  },
  extra_item_progress = {
    total = 12,
    done = 7,
    pending = 0,
    tooltip = "Extra items: 7 ready · 5 remaining",
    unfinished_items = {
      { item_name = "coal", count = 5 }
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
assert(hud_element.construction_progress.done.style.width == 128)
assert(hud_element.construction_progress.pending.style.width == 96)
assert(hud_element.construction_progress.not_started.style.width == 96)
assert(hud_element.construction_progress.done.style.bar_width == 6)
assert(hud_element.construction_progress.tooltip == "Construction: 4 placed · 3 ready to place · 3 remaining")
assert(hud_element.construction_shortfalls.entry_1.item_icon.sprite == "item/stone-furnace")
assert(hud_element.construction_shortfalls.entry_1.item_icon.style.width == 8)
assert(hud_element.construction_shortfalls.entry_1.quantity.caption == "3")
assert(hud_element.construction_shortfalls.style.maximal_width == 320)
assert(hud_element.construction_shortfalls.entry_1.style.width == 36)
assert(hud_element.research_progress.done.style.width == 80)
assert(hud_element.research_progress.pending.style.width == 160)
assert(hud_element.research_progress.not_started.style.width == 80)
assert(hud_element.research_progress.tooltip == "Research: 5 complete · 10 science ready · 5 remaining")
assert(hud_element.research_shortfalls.entry_1.item_icon.sprite == "item/automation-science-pack")
assert(hud_element.research_shortfalls.entry_1.quantity.caption == "5")
assert(hud_element.extra_item_progress.done.style.width == 186)
assert(hud_element.extra_item_progress.pending.visible == false)
assert(hud_element.extra_item_progress.not_started.style.width == 134)
assert(hud_element.extra_item_progress.tooltip == "Extra items: 7 ready · 5 remaining")
assert(hud_element.extra_item_shortfalls.entry_1.item_icon.sprite == "item/coal")
assert(hud_element.extra_item_shortfalls.entry_1.quantity.caption == "5")

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
assert(hud_element.construction_shortfalls.visible == false)
assert(hud_element.research_shortfalls.visible == false)
assert(hud_element.extra_item_shortfalls.visible == false)

hud.refresh(player, nil)
assert(left.long_pole_speedrun_hud ~= nil)
assert(header.active_speedrun_name.caption == "No active speedrun")
assert(hud_element.previous_split.visible == false)
assert(hud_element.current_split.visible == false)
assert(hud_element.long_pole_advance_split.visible == false)
assert(hud_element.construction_shortfalls.visible == false)
assert(hud_element.research_shortfalls.visible == false)
assert(hud_element.extra_item_shortfalls.visible == false)
assert(header.long_pole_next_plan.sprite == "utility/right_arrow")
