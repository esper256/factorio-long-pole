local M = {}

M.icon_name = "long_pole_item_progress_icon_button"
M.progress_name = "long_pole_item_progress_bar"

local DEFAULT_SLOT_SIZE = 40
local DEFAULT_PROGRESS_BAR_WIDTH = 4
local DEFAULT_PROGRESS_COLOR = {r = 0.24, g = 0.72, b = 0.32}

local function clamp_progress(progress)
  if progress == nil then
    return nil
  end

  local numeric = tonumber(progress)
  if not numeric then
    return nil
  end

  if numeric < 0 then
    return 0
  end
  if numeric > 1 then
    return 1
  end

  return numeric
end

local function resolve_sprite(entry)
  if not entry then
    return nil
  end

  if entry.sprite then
    return entry.sprite
  end

  if entry.kind and entry.name then
    return ("%s/%s"):format(entry.kind, entry.name)
  end

  if entry.name and entry.name ~= "" then
    return "item/" .. entry.name
  end

  return nil
end

local function progress_percent_label(progress)
  if progress == nil then
    return nil
  end

  return ("%d%%"):format(math.floor((progress * 100) + 0.5))
end

local function resolve_tooltip(entry, progress)
  if not entry then
    return nil
  end

  if entry.tooltip ~= nil then
    return entry.tooltip
  end

  local title = entry.localised_name or entry.name or "Unknown"
  local tooltip = {"", title}

  if entry.count ~= nil then
    tooltip[#tooltip + 1] = "\nAmount: "
    tooltip[#tooltip + 1] = tostring(entry.count)
  end

  if progress ~= nil then
    tooltip[#tooltip + 1] = "\nProgress: "
    tooltip[#tooltip + 1] = progress_percent_label(progress)
  end

  return tooltip
end

local function build_tags(options, entry)
  if type(options.build_tags) ~= "function" then
    return nil
  end

  return options.build_tags(entry)
end

local function icon_element(root)
  return root[M.icon_name] or root.children[1]
end

local function progress_element(root)
  return root[M.progress_name] or root.children[2]
end

-- Keep callers on a data-only contract so we can iterate on presentation here.
function M.add(parent, entry, options)
  options = options or {}

  local root = parent.add({
    type = "flow",
    name = options.name,
    direction = "vertical"
  })
  root.style.vertical_spacing = options.vertical_spacing or 1

  local button = root.add({
    type = "sprite-button",
    name = M.icon_name,
    sprite = options.empty_sprite,
    tooltip = options.empty_tooltip,
    tags = build_tags(options, entry)
  })
  button.style = options.button_style or "slot_button"
  button.style.width = options.slot_size or DEFAULT_SLOT_SIZE
  button.style.height = options.slot_size or DEFAULT_SLOT_SIZE
  button.style.clicked_vertical_offset = 0

  if options.button_name then
    button.name = options.button_name
  else
    button.ignored_by_interaction = true
  end

  local progress = root.add({
    type = "progressbar",
    name = M.progress_name,
    value = 0
  })
  progress.style.width = options.slot_size or DEFAULT_SLOT_SIZE
  progress.style.bar_width = options.progress_bar_width or DEFAULT_PROGRESS_BAR_WIDTH

  M.set_data(root, entry, options)
  return root
end

function M.set_data(root, entry, options)
  options = options or {}

  local button = icon_element(root)
  local progress = progress_element(root)
  local normalized_progress = clamp_progress(entry and entry.progress or nil)
  local sprite = resolve_sprite(entry) or options.empty_sprite

  if button then
    button.sprite = sprite
    button.number = entry and entry.count or nil
    button.quality = entry and entry.quality or nil
    button.tooltip = resolve_tooltip(entry, normalized_progress) or options.empty_tooltip
    button.enabled = entry and entry.enabled ~= false or options.button_enabled ~= false
    button.style.draw_grayscale_picture = entry and entry.desaturate == true or false
  end

  if progress then
    progress.visible = normalized_progress ~= nil and options.show_progress ~= false
    progress.value = normalized_progress or 0
    progress.style.color = entry and entry.progress_color or options.progress_color or DEFAULT_PROGRESS_COLOR
  end

  return root
end

return M
