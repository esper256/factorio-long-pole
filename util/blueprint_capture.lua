local blueprint_snapshot = require("blueprint_snapshot")
local blueprint_library = require("blueprint_library")
local cursor_blueprint_source = require("util.cursor_blueprint_source")
local description_codec = require("util.description_codec")
local safe_index = require("util.safe_index")

local M = {}

function M.capture_held_blueprint(player)
  local resolved, error_message = cursor_blueprint_source.resolve_selected_blueprint(player)
  if not resolved then
    return nil, error_message
  end

  local source = resolved.source
  local export_string = source.export_record and source.export_record() or source.export_stack()
  local entities = source.get_blueprint_entities and source.get_blueprint_entities() or {}
  local entity_count = source.get_blueprint_entity_count and source.get_blueprint_entity_count() or 0
  local library_match = blueprint_library.find_blueprint_path_by_export(player, export_string, game)
  local blueprint_name = safe_index.get(source, "label")
  local entity_summary = blueprint_snapshot.summarize_entities(entities)
  if not entity_summary or #entity_summary == 0 then
    local counts = {}
    for _, entity in ipairs(entities or {}) do
      if entity.name and entity.name ~= "" then
        counts[entity.name] = (counts[entity.name] or 0) + 1
      end
    end
    entity_summary = {}
    for name, count in pairs(counts) do
      entity_summary[#entity_summary + 1] = {name = name, count = count}
    end
    table.sort(entity_summary, function(a, b)
      if a.count == b.count then
        return a.name < b.name
      end
      return a.count > b.count
    end)
  end

  if not blueprint_name or blueprint_name == "" then
    if resolved.carrier == "cursor_record" then
      blueprint_name = blueprint_snapshot.resolve_name_from_export(export_string, "Unnamed Blueprint")
    else
      blueprint_name = "Unnamed Blueprint"
    end
  end

  return {
    name = blueprint_name,
    export_string = export_string,
    entity_count = entity_count,
    entity_summary = entity_summary,
    fingerprint = description_codec.fingerprint_from_entity_summary(entity_summary),
    library_root = library_match and library_match.library_root or "player-blueprints",
    inside_books = library_match and library_match.inside_books or nil,
    blueprint_slot = library_match and library_match.blueprint_slot or resolved.source_book_active_index,
    source_book_label = resolved.source_book_label,
    source_book_active_index = resolved.source_book_active_index
  }, nil
end

return M
