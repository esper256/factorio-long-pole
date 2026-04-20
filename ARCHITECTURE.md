# Architecture

## Purpose

This mod is intended to help people practice speedrunning **Factorio** version 2.0.76 including compatability with Space Age.

The general use case is:

1. Design a speedrunning plan (often called a set of *splits*), e.g.
   - Mine one coal rock.
   - Place the starter burner mining drill and furnace.
   - Craft another burner mining drill and furnace and place them.
   - Mine 500+ coal from coal rocks.
   - Build a blueprint containing a boiler, steam engine, lab, and 10 red science packs.
2. Run the plan in-game.
3. Use the mod to identify which part of the current split is predicted to take the longest (the “long pole”).

Example: if the mod indicates **gear wheel assembly** is the long pole, the player should prioritize feeding iron plates into gear wheel assemblers before feeding electronic circuit assemblers.

## Core design philosophy

The mod maintains an internal tally of what the player has access to by registering for Factorio events that indicate items are:

- created
- consumed
- destroyed

This tally must account for items located across multiple places, including:

- the player’s inventory
- chests (e.g., buffer chests, logistics chests)
- items on transport belts
- machine inventories (e.g., assembling machines)

The internal tally is compared against the current split’s requirements to determine what is still missing. Combined with recent production rates, the mod estimates which requirement is most likely to be the long pole.

## Major mod components

The mod is split into two primary parts:

### 1) Split viewer (in-game display)

An in-game display in the **upper-left** corner showing a vertical stack of rows representing splits the player cares about.

Default behavior (configurable via settings):

- Previous split at the top
- Current in-progress split directly below
- A configurable number of upcoming splits below the current split

Each split should have the following columns:
- The name of the split (Power plant, On-patch burners, etc)
- The elapsed time compared to previous best timing on the split -3:02 would mean 3 minutes 2 seconds faster than previous record, +1:06 would mean one minute and six seconds slower than fastest attempt at the split
- A truncated list of items that need to be produced for the split to be complete sorted by how long they are predicted to take before completing. This list should include two virtual items (lab research production as well as entities placed as a heuristic for player bluprint build speed)
- On the current split only an extra column that is a button for completing the split and advancing to the next one. This one should turn green once the mod predicts all intended production, build and research objectives have been completed.

### 2) Plan editor (speedrun plan editor)

A large popup window (nearly full screen) for editing the list of splits.

Each split includes:

- a name
- a list of blueprints the player intends to build
- a list of additional items (beyond what the blueprints include)
- a list of technologies to research before proceeding to the next split

The editor also surfaces supporting information to help with planning decisions, such as:

- the raw resource cost of every entity combined in each blueprint
- the total entity count of each blueprint

Undecided: Many blueprints are staged in that they include items from the previous blueprint in addition to the new entities. There needs to be some way to not double count the old entitities that were already build in a previous blueprint.

## Persistent plan storage and cross-save transfer

Speedrunners need to be able to design a plan in one save, then start a fresh run and load that same plan immediately. The preferred transport mechanism is the player's blueprint library / blueprint book system, because that already supports moving data between saves and is the most likely path to Steam Cloud synchronization.

### Requirements

- Plans must survive across saves without requiring external files.
- Importing a plan into a fresh save should be fast and mostly one click.
- Large plans must not depend on long visible text fields that clutter the UI or make blueprint tooltips expensive to render.
- The storage format should be versioned so that future mod releases can migrate old plans.
- The in-save working copy of the plan should remain in `storage`; the portable copy is an explicit export artifact.

### Recommended design: portable plan book

The mod should support exporting a run plan into a dedicated **plan blueprint book** stored in the player's blueprint library.

The blueprint book should contain:

- A short user-visible label such as `Any% Practice Plan` or `Space Age Route v3`.
- One or more blueprint entries used as **plan data carriers**.
- Optional human-readable blueprint descriptions kept intentionally short.

Each carrier blueprint should store the actual plan payload in **blueprint entity tags**, not in the blueprint description. This avoids rendering a giant wall of serialized text in normal UI surfaces while still piggybacking on blueprint import/export and library persistence.

### Why blueprint entity tags

Factorio does not provide a good generic hidden metadata field on blueprint items themselves. `label` and `blueprint_description` are visible to the player and are poor fits for large opaque payloads. By contrast, blueprint entity tags are designed for structured mod data attached to blueprint entities and are not intended as a user-facing text surface.

The export format should therefore use:

- A dedicated carrier blueprint.
- A single anchor entity inside that blueprint.
- A namespaced tag on that entity such as `long-pole.plan_chunk`.

The anchor entity exists only to give the blueprint somewhere to hold hidden tags. The player does not need to place the blueprint in the world for import/export to work.

### Payload format

The payload stored in the carrier blueprint should be:

1. A normalized Lua table representation of the run plan.
2. Serialized to JSON.
3. Compressed with `helpers.encode_string()`.
4. Split into chunks when necessary.

Each chunk should include lightweight metadata:

- `format = "long-pole-plan"`
- `schema_version = 1`
- `plan_id`
- `chunk_index`
- `chunk_count`
- `payload`
- `checksum` or lightweight integrity hash

The full logical plan should include:

- Plan-level metadata: plan name, author label if present, exported-at version, Factorio major/minor compatibility target.
- Ordered split list.
- For each split: name, blueprint references/import strings as needed, extra items, technologies, notes, and any staged-blueprint accounting rules.

### Handling large plans

Blueprint metadata can grow large enough to become awkward if all data is forced into one visible field or one monolithic blob. To keep the system resilient:

- Do not store the plan in `blueprint_description` except for a short summary.
- Allow the plan book to contain multiple carrier blueprints, each holding one chunk.
- Keep each chunk independently decodable and indexed.
- Keep the first carrier blueprint small and obvious so it can serve as the user-facing "entry point" for import.

This chunked-book design gives the mod room to support very large plans without betting everything on the practical size limits of one blueprint entry.

### Import workflow

The import workflow should be:

1. Player opens the plan editor in a fresh save.
2. Player clicks `Import from Blueprint Book`.
3. The mod scans the selected blueprint book or blueprint item for `long-pole` carrier tags.
4. The mod reassembles chunks, validates schema version/checksum, and decodes the JSON.
5. The decoded plan becomes the save's working plan in `storage.splits`.

The export workflow should be the inverse:

1. Player clicks `Export to Blueprint Book`.
2. The mod creates or updates a dedicated plan blueprint book in the player's library or cursor.
3. The plan is serialized, compressed, chunked, and written into carrier blueprint entity tags.

### Save-local data versus portable data

Two copies of plan data are acceptable and intentional:

- `storage.splits` is the live editable copy used by the current save.
- The blueprint book is a portable snapshot used for transfer, backup, and sharing.

The mod should not continuously rewrite blueprint-library data on every edit. Export should be a deliberate action so that editing remains cheap and predictable.

### Fallbacks and compatibility

The architecture should support fallback import/export methods later, but they should be secondary:

- Export/import via blueprint string text.
- Export/import via `script-output` JSON for advanced users.
- Migration of old schema versions on import.

If blueprint-carried metadata ever proves too small in practice, the next fallback should still be blueprint-book based: multiple chunks across multiple carrier blueprints before considering visible text fields.

## Engineering approach

- Ensure the mod works as designed and the GUI is intuitive.
- Maintain Factorio performance for bases typical of speedrunning (not megabases).
- Provide tests that validate the mod’s logic without requiring Factorio to be launched.
