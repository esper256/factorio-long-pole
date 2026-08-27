-- Keeps the visible quickbar pointed at the active split's source page.
-- Plans retain only the source page number; this module resolves the live
-- blueprint-library record at the instant Factorio needs it.
local blueprint_book_plan_loader = require("storage.blueprint_book_plan_loader")

local M = {}

local function source_page_index(book, attempt, split)
  local page_index = split:source_page()
  if page_index then
    return page_index
  end

  -- Attempts saved before source-page locators existed can still be used. This
  -- only orders top-level pages once; it never reads any blueprint contents.
  local indexes = {}
  for index in pairs(book.contents) do
    indexes[#indexes + 1] = index
  end
  table.sort(indexes)
  return indexes[attempt.current_split_index]
end

local function current_split_record(player, attempt)
  local split = attempt:current_split()
  if not split then
    return nil
  end

  local book, resolved_index = blueprint_book_plan_loader.find_library_book(
    player,
    attempt.library_book_label or attempt.plan.label,
    attempt.library_book_index
  )
  if resolved_index then
    attempt.library_book_index = resolved_index
  end
  if not book or book.type ~= "blueprint-book" then
    return nil
  end

  local page_index = source_page_index(book, attempt, split)
  if not page_index then
    return nil
  end
  return book.contents[page_index]
end

function M.update(player, attempt)
  if not attempt:current_split() then
    return false
  end

  local record = current_split_record(player, attempt)
  if not record then
    player.print("[Long Pole] The current split's source blueprint is no longer in your library.")
    return false
  end

  player.set_quick_bar_slot(1, player.quick_bar_width, {
    type = "record",
    record = record
  })
  return true
end

return M
