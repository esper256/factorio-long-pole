-- Loads portable speedrun plans from blueprint books.
--
-- Other features should depend on this module and the returned speedrun_plan
-- object, never on blueprint descriptions or the Factorio blueprint API.
--
-- A split may be one blueprint or one flat blueprint book. In either case, the
-- top-level split item owns this block; a split book's child blueprints only
-- contribute their entities. Text outside the markers is left for the plan
-- author's notes.
--
--   ====== long-pole data-begin ======
--   # Comments and blank lines are ignored.
--   research automation
--   item iron-plate 8
--   item coal 50
--   ====== long-pole data-end ======
--
-- `research` takes one technology prototype name. `item` takes one item
-- prototype name and a positive whole-number required count. Repeated item
-- lines add their counts together.
local speedrun_plan = require("speedrun_plan.plan")

local M = {}

local DATA_BEGIN = "====== long-pole data-begin ======"
local DATA_END = "====== long-pole data-end ======"

local function non_empty_label(page, location)
  if type(page.label) ~= "string" or page.label == "" then
    return nil, location .. " needs a blueprint label"
  end
  return page.label
end

local function is_blueprint(page)
  return page.is_blueprint == true or page.type == "blueprint"
end

local function is_blueprint_book(page)
  return page.is_blueprint_book == true or page.type == "blueprint-book"
end

local function blueprint_entity_counts(page)
  local counts = {}
  local entities = page.get_blueprint_entities() or {}

  for _, entity in pairs(entities) do
    counts[entity.name] = (counts[entity.name] or 0) + 1
  end

  return counts
end

local function add_entity_counts(total, counts)
  for entity_name, count in pairs(counts) do
    total[entity_name] = (total[entity_name] or 0) + count
  end
end

local function read_flat_blueprint(page, location)
  if not is_blueprint(page) then
    return nil, location .. " must be a blueprint, not a nested book or planner"
  end
  return blueprint_entity_counts(page)
end

local function read_flat_stack_book(book, location)
  local inventory = book.get_inventory(defines.inventory.item_main)
  if not inventory then
    return nil, location .. " has no item-main inventory"
  end

  local counts = {}
  for index = 1, #inventory do
    local page = inventory[index]
    if page.valid_for_read then
      local page_counts, page_error = read_flat_blueprint(page, location .. " page " .. index)
      if not page_counts then
        return nil, page_error
      end
      add_entity_counts(counts, page_counts)
    end
  end
  return counts
end

local function read_flat_record_book(book, location)
  local counts = {}
  for index, page in pairs(book.contents) do
    local page_counts, page_error = read_flat_blueprint(page, location .. " page " .. index)
    if not page_counts then
      return nil, page_error
    end
    add_entity_counts(counts, page_counts)
  end
  return counts
end

local function read_split_book(book, location)
  local label, label_error = non_empty_label(book, location)
  if not label then
    return nil, label_error
  end

  local counts, counts_error
  if book.type ~= nil then
    counts, counts_error = read_flat_record_book(book, location)
  else
    counts, counts_error = read_flat_stack_book(book, location)
  end
  if not counts then
    return nil, counts_error
  end

  return {
    label = label,
    description = book.blueprint_description or "",
    entity_counts = counts
  }
end

local function read_split(page, location)
  local label, label_error = non_empty_label(page, location)
  if not label then
    return nil, label_error
  end

  if is_blueprint(page) then
    return {
      label = label,
      description = page.blueprint_description or "",
      entity_counts = blueprint_entity_counts(page)
    }
  end
  if is_blueprint_book(page) then
    return read_split_book(page, location)
  end
  return nil, location .. " must be a blueprint or a flat blueprint book"
end

local function read_stack_book(book)
  if book.is_blueprint_book ~= true then
    return nil, "expected a blueprint book item"
  end

  local inventory = book.get_inventory(defines.inventory.item_main)
  if not inventory then
    return nil, "blueprint book has no item-main inventory"
  end

  local pages = {}
  for index = 1, #inventory do
    local page = inventory[index]
    if page.valid_for_read then
      local split, page_error = read_split(page, "book page " .. index)
      if not split then
        return nil, page_error
      end
      pages[#pages + 1] = split
    end
  end

  return pages
end

local function read_record_book(book)
  if book.type ~= "blueprint-book" then
    return nil, "expected a blueprint-book library record"
  end

  local indexes = {}
  for index in pairs(book.contents) do
    indexes[#indexes + 1] = index
  end
  table.sort(indexes)

  local pages = {}
  for _, index in ipairs(indexes) do
    local split, page_error = read_split(book.contents[index], "book page " .. index)
    if not split then
      return nil, page_error
    end
    pages[#pages + 1] = split
  end

  return pages
end

local function read_book(book)
  if book.type ~= nil then
    return read_record_book(book)
  end
  return read_stack_book(book)
end

local function trim(text)
  return text:match("^%s*(.-)%s*$")
end

local function add_count(counts, name, count)
  counts[name] = (counts[name] or 0) + count
end

local function parse_count(text, context)
  local count = tonumber(text)
  if not count or count <= 0 or count % 1 ~= 0 then
    return nil, context .. " needs a positive whole-number count"
  end
  return count
end

local function parse_directive(line, metadata, context)
  local technology = line:match("^research%s+([%w_%-]+)$")
  if technology then
    metadata.research_technologies[technology] = true
    return true
  end

  local item_name, count_text = line:match("^item%s+([%w_%-]+)%s+(%S+)$")
  if item_name then
    local count, count_error = parse_count(count_text, context .. " item " .. item_name)
    if not count then
      return nil, count_error
    end
    add_count(metadata.extra_item_counts, item_name, count)
    return true
  end

  return nil, context .. " has an unknown directive: " .. line
end

local function parse_metadata(description, split_label)
  local metadata = {
    extra_item_counts = {},
    research_technologies = {}
  }
  local found_begin = false
  local found_end = false
  local line_number = 0

  for raw_line in (description .. "\n"):gmatch("(.-)\n") do
    line_number = line_number + 1
    local line = trim(raw_line:gsub("\r$", ""))

    if line == DATA_BEGIN then
      if found_begin then
        return nil, split_label .. " has more than one long-pole data block"
      end
      found_begin = true
    elseif line == DATA_END then
      if not found_begin or found_end then
        return nil, split_label .. " has an unmatched long-pole data end marker"
      end
      found_end = true
    elseif found_begin and not found_end and line ~= "" and line:sub(1, 1) ~= "#" then
      local parsed, parse_error = parse_directive(line, metadata, split_label .. " description line " .. line_number)
      if not parsed then
        return nil, parse_error
      end
    end
  end

  if found_begin and not found_end then
    return nil, split_label .. " is missing the long-pole data end marker"
  end
  if not found_begin and description:find(DATA_END, 1, true) then
    return nil, split_label .. " has a long-pole data end marker without a begin marker"
  end

  return metadata
end

function M.is_speedrun_plan_book(book)
  return book ~= nil
    and type(book.label) == "string"
    and book.label:sub(-4) == "[LP]"
end

-- Loads a complete, cheap-to-query snapshot. A returned plan contains no
-- Factorio LuaObjects, so later HUD/progress code never rescans blueprints.
-- Invalid player-authored books return nil plus an explanatory error.
function M.load_book(book)
  if not M.is_speedrun_plan_book(book) then
    return nil, "blueprint book label must end with [LP]"
  end

  local pages, read_error = read_book(book)
  if not pages then
    return nil, read_error
  end
  if #pages == 0 then
    return nil, "speedrun plan book has no blueprint splits"
  end

  local splits = {}
  for index, page in ipairs(pages) do
    local metadata, metadata_error = parse_metadata(page.description, page.label)
    if not metadata then
      return nil, metadata_error
    end
    metadata.label = page.label
    metadata.entity_counts = page.entity_counts
    splits[index] = metadata
  end

  return speedrun_plan.new(book.label, splits)
end

-- Runtime callers with a player should use this entry point. In particular,
-- the label guard runs before the book reader can inspect any blueprint pages.
function M.load_book_for_player(player, book)
  local plan, load_error = M.load_book(book)
  if not plan then
    player.print("[Long Pole] " .. load_error)
  end
  return plan, load_error
end

-- Finds the next top-level [LP] book after a blueprint-library index. Unmarked
-- books are identified from their label only and are never opened or parsed.
function M.load_next_library_book_for_player(player, after_index)
  for index = after_index + 1, #player.blueprints do
    local book = player.blueprints[index]
    if M.is_speedrun_plan_book(book) then
      local plan, load_error = M.load_book_for_player(player, book)
      if not plan then
        return nil, nil, load_error
      end
      return plan, index
    end
  end

  player.print("[Long Pole] No later [LP] blueprint book was found in your library.")
  return nil
end

return M
