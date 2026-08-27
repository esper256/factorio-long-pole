-- Icon lists must update existing children in place and destroy extras
-- instead of rebuilding the row on every pulse.
local function element(parent, specification)
  local child = {
    name = specification.name or "",
    caption = specification.caption,
    sprite = specification.sprite,
    tooltip = specification.tooltip,
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

local parent = {
  child_names = {}
}
parent.add = function(specification)
  local child = element(parent, specification)
  parent[child.name] = child
  parent.child_names[child.name] = true
  return child
end

local icon_quantity_list = require("hud.icon_quantity_list")
local list = icon_quantity_list.add(parent, "shortfalls", 192)
icon_quantity_list.refresh(list, {
  { item_name = "iron-gear-wheel", count = 12 },
  { item_name = "coal", count = 40 }
})

local first_pair = list.entry_1
assert(list.style.horizontal_spacing == 0)
assert(first_pair.item_icon.sprite == "item/iron-gear-wheel")
assert(first_pair.item_icon.style.width == 8)
assert(first_pair.item_icon.style.height == 8)
assert(first_pair.quantity.caption == "12")
assert(list.entry_2.quantity.caption == "40")

icon_quantity_list.refresh(list, {
  { item_name = "coal", count = 7 }
})
assert(list.entry_1 == first_pair)
assert(list.entry_1.item_icon.sprite == "item/coal")
assert(list.entry_1.quantity.caption == "7")
assert(list.entry_2 == nil)

icon_quantity_list.refresh(list, {})
assert(list.visible == false)
assert(list.entry_1 == nil)
