local blueprint_fingerprint = require("util.blueprint_fingerprint")

local M = {}

-- Long Pole stores plan data inside blueprint descriptions on purpose: the
-- payload needs to round-trip through ordinary blueprint books, survive across
-- saves, and stay inspectable enough that humans can debug bad metadata by eye.

M.example_plan_description = [[format=long-pole-plan;version=1
plan_id=plan-42
visibility=references-only
default_surface=nauvis
]]

M.example_split_description = [[format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
transport-belt=200
iron-chest=3

--- Technologies to Research ---
automation
logistics

--- Notes ---
Feed gears before circuits.
]]

M.example_blueprint_link_description = [[format=long-pole-blueprint-link;version=1
link_mode=reference
library_root=player-blueprints
inside_book=Any% Openers
inside_book=Burner Starts
inside_book=Safe Variants
blueprint_name=Starter burner pair
blueprint_slot=2
blueprint_fingerprint=burner-mining-drill:2;stone-furnace:2
]]

M.example_blueprint_link_root_description = [[format=long-pole-blueprint-link;version=1
link_mode=reference
library_root=player-blueprints
blueprint_name=Direct Library Blueprint
blueprint_slot=7
blueprint_fingerprint=transport-belt:12;inserter:4
]]

local SECTION_HEADER_PATTERN = "^%-%-%- (.+) %-%-%-$"

local function split_lines(value)
  -- Blueprint descriptions can pick up mixed line endings from copy/paste or
  -- manual edits, so normalize them before parsing sections.
  local normalized = (value or ""):gsub("\r\n", "\n"):gsub("\r", "\n")
  local lines = {}
  if normalized == "" then
    return lines
  end

  if normalized:sub(-1) ~= "\n" then
    normalized = normalized .. "\n"
  end

  for line in normalized:gmatch("([^\n]*)\n") do
    lines[#lines + 1] = line
  end

  return lines
end

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function split_first(value, separator)
  local first, last = value:find(separator, 1, true)
  if not first then
    return value, nil
  end

  return value:sub(1, first - 1), value:sub(last + 1)
end

local function serialize_header(format_name, version)
  return ("format=%s;version=%s"):format(format_name, tostring(version or 1))
end

local function parse_header(line)
  local parsed = {}
  for token in (line or ""):gmatch("[^;]+") do
    local key, value = split_first(token, "=")
    key = trim(key)
    if not key or key == "" or value == nil then
      return nil, "Description header must be key=value pairs separated by semicolons."
    end
    parsed[key] = trim(value)
  end

  if not parsed.format or parsed.format == "" then
    return nil, "Description header is missing format."
  end

  local version = tonumber(parsed.version)
  if not version then
    return nil, "Description header is missing version."
  end

  parsed.version = math.floor(version)
  return parsed
end

local function append_key_value(lines, key, value)
  if value == nil or value == "" then
    return
  end
  lines[#lines + 1] = ("%s=%s"):format(key, tostring(value))
end

local function normalize_items(items)
  local normalized = {}
  for _, item in ipairs(items or {}) do
    if item.name and item.name ~= "" then
      normalized[#normalized + 1] = {
        name = item.name,
        count = math.max(1, math.floor(tonumber(item.count) or 1))
      }
    end
  end
  return normalized
end

local function normalize_technologies(technologies)
  local normalized = {}
  local seen = {}
  for _, technology in ipairs(technologies or {}) do
    local name = trim(technology.name)
    if name ~= "" and not seen[name] then
      seen[name] = true
      normalized[#normalized + 1] = {
        name = name
      }
    end
  end
  return normalized
end

local function export_plan_description(data)
  local lines = {
    serialize_header("long-pole-plan", 1)
  }

  append_key_value(lines, "plan_id", data.plan_id)
  append_key_value(lines, "visibility", data.visibility or "references-only")
  append_key_value(lines, "default_surface", data.default_surface)

  return table.concat(lines, "\n") .. "\n"
end

local function export_split_description(data)
  local lines = {
    serialize_header("long-pole-split", 1),
    ("surface=%s"):format(data.surface or "nauvis"),
    "",
    "--- Extra Items ---"
  }

  for _, item in ipairs(normalize_items(data.items)) do
    lines[#lines + 1] = ("%s=%d"):format(item.name, item.count)
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "--- Technologies to Research ---"
  for _, technology in ipairs(normalize_technologies(data.technologies)) do
    lines[#lines + 1] = technology.name
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "--- Notes ---"
  for _, note_line in ipairs(split_lines(data.notes or "")) do
    lines[#lines + 1] = note_line
  end

  return table.concat(lines, "\n") .. "\n"
end

local function export_blueprint_link_description(data)
  local lines = {
    serialize_header("long-pole-blueprint-link", 1),
    ("link_mode=%s"):format(data.link_mode or "reference"),
    ("library_root=%s"):format(data.library_root or "player-blueprints")
  }

  local inside_books = data.inside_books or {}
  -- Preserve at least the immediate source book name when a full nested path is
  -- unavailable so refresh still has one human-meaningful breadcrumb.
  if #inside_books == 0 and data.source_book_label and data.source_book_label ~= "" then
    inside_books = {data.source_book_label}
  end

  for _, book_name in ipairs(inside_books) do
    append_key_value(lines, "inside_book", book_name)
  end

  append_key_value(lines, "blueprint_name", data.blueprint_name or data.name)
  append_key_value(lines, "blueprint_slot", data.blueprint_slot or data.source_book_active_index)

  local stored_blueprint_fingerprint = data.blueprint_fingerprint
  if not stored_blueprint_fingerprint or stored_blueprint_fingerprint == "" then
    stored_blueprint_fingerprint = blueprint_fingerprint.from_entity_summary(data.entity_summary)
  end
  append_key_value(lines, "blueprint_fingerprint", stored_blueprint_fingerprint)

  return table.concat(lines, "\n") .. "\n"
end

local function parse_root_lines(lines, start_index)
  local root = {}
  local repeated = {
    inside_book = true
  }
  local index = start_index

  while index <= #lines do
    local line = lines[index]
    if line:match(SECTION_HEADER_PATTERN) then
      break
    end

    if trim(line) ~= "" then
      local key, value = split_first(line, "=")
      key = trim(key)
      if not key or key == "" or value == nil then
        return nil, nil, "Expected key=value line."
      end

      if repeated[key] then
        -- Nested blueprint-book paths are stored as repeated keys so the
        -- serialized format stays easy to inspect and append to manually.
        root[key] = root[key] or {}
        root[key][#root[key] + 1] = value
      else
        root[key] = value
      end
    end

    index = index + 1
  end

  return root, index
end

local function parse_split_sections(lines, start_index)
  local sections = {}
  local current_section = nil

  for index = start_index, #lines do
    local line = lines[index]
    local section_name = line:match(SECTION_HEADER_PATTERN)
    if section_name then
      current_section = section_name
      sections[current_section] = sections[current_section] or {}
    elseif current_section then
      sections[current_section][#sections[current_section] + 1] = line
    elseif trim(line) ~= "" then
      return nil, "Unexpected content before first section."
    end
  end

  return sections
end

local function trim_trailing_empty_lines(lines)
  local last_index = #lines
  while last_index > 0 and lines[last_index] == "" do
    last_index = last_index - 1
  end

  local trimmed = {}
  for index = 1, last_index do
    trimmed[index] = lines[index]
  end
  return trimmed
end

local function import_plan_description(lines, header)
  local root, _, error_message = parse_root_lines(lines, 2)
  if not root then
    return nil, error_message
  end

  return {
    format = header.format,
    version = header.version,
    plan_id = root.plan_id,
    visibility = root.visibility or "references-only",
    default_surface = root.default_surface or "nauvis"
  }
end

local function import_split_description(lines, header)
  local root, next_index, error_message = parse_root_lines(lines, 2)
  if not root then
    return nil, error_message
  end

  local sections, section_error = parse_split_sections(lines, next_index)
  if not sections then
    return nil, section_error
  end

  local items = {}
  for _, line in ipairs(sections["Extra Items"] or {}) do
    if trim(line) ~= "" then
      local name, count_text = split_first(line, "=")
      local count = math.floor(tonumber(count_text) or 0)
      name = trim(name)
      if name ~= "" and count > 0 then
        items[#items + 1] = {
          name = name,
          count = count
        }
      end
    end
  end

  local technologies = {}
  local seen = {}
  for _, line in ipairs(sections["Technologies to Research"] or {}) do
    local name = trim(line)
    if name ~= "" and not seen[name] then
      seen[name] = true
      technologies[#technologies + 1] = {
        name = name
      }
    end
  end

  local notes_lines = trim_trailing_empty_lines(sections["Notes"] or {})
  return {
    format = header.format,
    version = header.version,
    surface = root.surface or "nauvis",
    items = items,
    technologies = technologies,
    notes = table.concat(notes_lines, "\n")
  }
end

local function import_blueprint_link_description(lines, header)
  local root, _, error_message = parse_root_lines(lines, 2)
  if not root then
    return nil, error_message
  end

  local stored_blueprint_fingerprint = root.blueprint_fingerprint or root.fingerprint or ""
  local entity_summary, entity_count = blueprint_fingerprint.entity_summary_from_blueprint_fingerprint(stored_blueprint_fingerprint)
  local inside_books = root.inside_book or {}
  local first_inside_book = inside_books[1]
  local blueprint_slot = tonumber(root.blueprint_slot)
  if blueprint_slot then
    blueprint_slot = math.floor(blueprint_slot)
  end

  return {
    format = header.format,
    version = header.version,
    link_mode = root.link_mode or "reference",
    library_root = root.library_root or "player-blueprints",
    inside_books = inside_books,
    blueprint_name = root.blueprint_name,
    blueprint_slot = blueprint_slot,
    blueprint_fingerprint = stored_blueprint_fingerprint,
    name = root.blueprint_name,
    source_book_label = first_inside_book,
    source_book_active_index = blueprint_slot,
    entity_summary = entity_summary,
    entity_count = entity_count
  }
end

function M.export_to_description(data)
  if type(data) ~= "table" then
    return nil, "description data must be a table"
  end

  if data.format == "long-pole-plan" then
    return export_plan_description(data)
  end

  if data.format == "long-pole-split" then
    return export_split_description(data)
  end

  if data.format == "long-pole-blueprint-link" then
    return export_blueprint_link_description(data)
  end

  return nil, ("unsupported description format: %s"):format(tostring(data.format))
end

function M.import_from_description(description)
  if type(description) ~= "string" then
    return nil, "description must be a string"
  end

  local lines = split_lines(description)
  if #lines == 0 then
    return nil, "description is empty"
  end

  local header, error_message = parse_header(lines[1])
  if not header then
    return nil, error_message
  end

  if header.format == "long-pole-plan" then
    return import_plan_description(lines, header)
  end

  if header.format == "long-pole-split" then
    return import_split_description(lines, header)
  end

  if header.format == "long-pole-blueprint-link" then
    return import_blueprint_link_description(lines, header)
  end

  return nil, ("unsupported description format: %s"):format(header.format)
end

return M
