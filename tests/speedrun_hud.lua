-- The gameplay HUD creates a compact left-side flow, updates captions in
-- place, and stays visible with an empty state when there is no active plan.
local function element(parent, specification)
  local child = {
    type = specification.type,
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
  plan_label = "Any% practice [LP]",
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
      { item_name = "iron-gear-wheel", count = 7, eta_ticks = 720, produced_per_minute = 60 }
    }
  }
})

local hud_element = left.long_pole_speedrun_hud
local header = hud_element.speedrun_header
assert(hud_element ~= nil)
assert(hud_element.type == "flow")
assert(hud_element.style.padding == 0)
assert(hud_element.style.vertical_spacing == 0)
assert(hud_element.style.horizontal_spacing == nil)
assert(header.style.horizontal_spacing == 0)
assert(header.style.vertical_spacing == nil)
assert(hud_element.style.width == 192)
assert(header.game_clock == nil)
assert(hud_element.next_split_row == nil)
assert(header.active_speedrun_name.caption == "Any% practice")
assert(hud_element.current_split.type == "label")
assert(hud_element.current_split.caption == "Burner phase  1:01")
assert(hud_element.long_pole_advance_split.caption == "Automation")
assert(hud_element.previous_split.visible == false)
assert(header.long_pole_next_plan.sprite == "utility/right_arrow")
assert(header.long_pole_next_plan.style.width == 16)
assert(header.long_pole_next_plan.style.height == 16)
assert(hud_element.construction_progress.indicator_icon.sprite == "item/blueprint")
assert(hud_element.research_progress.indicator_icon.sprite == "utility/technology_white")
assert(hud_element.next_split_production_progress.indicator_icon.sprite == "item/iron-gear-wheel")
assert(hud_element.extra_item_progress == nil)
assert(hud_element.construction_progress.segments.done.style.width == 72)
assert(hud_element.construction_progress.segments.pending.style.width == 54)
assert(hud_element.construction_progress.segments.not_started.style.width == 54)
assert(hud_element.construction_progress.tooltip == "Construction: 4 placed · 3 ready to place · 3 remaining")
assert(hud_element.construction_shortfalls.entry_1.item_icon.sprite == "item/stone-furnace")
assert(hud_element.construction_shortfalls.entry_1.item_icon.style.width == 8)
assert(hud_element.construction_shortfalls.entry_1.quantity.caption == "3")
assert(hud_element.research_progress.tooltip == "Research: 5 consumed in labs · 15 remaining · 2 labs working")
assert(hud_element.research_shortfalls.entry_1.item_icon.sprite == "item/automation-science-pack")
assert(hud_element.next_split_production_progress.tooltip == "Next production: 3 ready · 7 remaining")
assert(hud_element.next_split_production_shortfalls.entry_1.item_icon.sprite == "item/iron-gear-wheel")
assert(hud_element.next_split_production_shortfalls.entry_1.quantity.caption == "12s")

hud.refresh(player, {
  plan_label = "Any% practice [LP]",
  previous_split_label = "Burner phase",
  previous_split_finished_tick = 3600,
  current_split_label = "Automation",
  game_tick = 3720
})

assert(header.active_speedrun_name.caption == "Any% practice")
assert(hud_element.previous_split.visible == true)
assert(hud_element.previous_split.caption == "Burner phase  1:00")
assert(hud_element.current_split.caption == "Automation  1:02")
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

-- A leftover framed HUD from an earlier revision must be rebuilt as a flow.
left.long_pole_speedrun_hud = {
  type = "frame",
  speedrun_header = {
    game_clock = { caption = "1:01" }
  },
  next_split_row = {},
  destroy = function()
    left.long_pole_speedrun_hud = nil
  end
}
hud.refresh(player, {
  plan_label = "Any% practice [LP]",
  current_split_label = "Burner phase",
  game_tick = 60
})
assert(left.long_pole_speedrun_hud.type == "flow")
assert(left.long_pole_speedrun_hud.current_split.caption == "Burner phase  0:01")
assert(left.long_pole_speedrun_hud.speedrun_header.game_clock == nil)
