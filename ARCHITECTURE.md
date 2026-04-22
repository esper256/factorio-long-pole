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
2. Start a new game and load the plan.
3. Use the mod to identify which part of the current split is predicted to take the longest (the “long pole”).

Example: if the mod indicates **gear wheel assembly** is the long pole, the player should prioritize feeding iron plates into gear wheel assemblers before feeding electronic circuit assemblers.

## Core design philosophy

The mod maintains an internal tally of what the player has access to by combining Factorio events and engine-maintained statistics to understand when items are:

- created
- consumed
- destroyed

This tally must account for items located across multiple places, including:

- the player’s inventory
- chests (e.g., buffer chests, logistics chests)
- items on transport belts
- machine inventories (e.g., assembling machines)

The internal tally is compared against the current split’s requirements to determine what is still missing. Combined with recent production rates, the mod estimates which requirement is most likely to be the long pole.

Split requirements are intentionally divided into different completion semantics:

- Blueprint entities are **placement goals**. A split is not done until those entities have been placed in the world.
- Extra items are **stock goals**. They only need to exist in loose stock so the player can move on with enough materials.
- Research entries are **completion goals**. The technology must actually be finished before the split is done.

The split after the current one gets a separate readiness view. It should answer: "if the player advanced right now, is there enough loose stock left over to place the next split's expected entities and supply its extra stock targets?" That next-split readiness signal must stay visually distinct from the current split's build-completion signal.

## Major mod components

The mod has three primary components.

### 1) Split progress visualizer and predictor

An in-game display in the **upper-left** corner showing a vertical stack of rows representing splits the player cares about.

Default behavior (configurable via settings):

- Previous split at the top
- Current in-progress split directly below
- A configurable number of upcoming splits below the current split

Each split should have the following columns:
- The name of the split (Power plant, On-patch burners, etc)
- The elapsed time compared to previous best timing on the split -3:02 would mean 3 minutes 2 seconds faster than previous record, +1:06 would mean one minute and six seconds slower than fastest attempt at the split
- For the current split, a truncated list of the missing items and intermediates sorted by how long they are predicted to take before the split is complete. Blueprint-backed items in this list represent **entities that still need to be placed**, while research-backed items represent **science and research still needed to finish the split**.
- For the next split, a separate readiness view showing whether enough loose stock exists to place the next split's required entities and satisfy its extra stock targets after reserving what the current split still needs.
- On the current split only an extra column that is a button for completing the split and advancing to the next one. This one should turn green once the mod predicts all intended production, build and research objectives have been completed.

### 2) Run plan editor

A large popup window (nearly full screen) for editing the list of splits.

The plan editor must be treated as a **dense information workspace**, not a spacious form UI. Speedrunners need to see many splits and many requirements at once, so packing efficiency is a default design goal rather than a later cleanup task.

Each split includes:

- a name
- a list of blueprints whose entities must be placed before the split is considered complete
- a list of additional stock items that should be available before moving on, but do not need to be placed
- a list of technologies that must be completed before proceeding to the next split

The editor also surfaces supporting information to help with planning decisions, such as:

- the raw resource cost of every entity combined in each blueprint
- the total entity count of each blueprint

The editor should label these columns using their completion semantics, not just their data type. A good default vocabulary is:

- `Constructed Blueprints`: entities from these blueprints must be placed in the world
- `Extra Stock`: these items only need to exist in loose stock
- `Completed Research`: these technologies must be finished

### Plan editor layout principles

The editor should follow a few explicit layout rules:

- Prefer compact controls over roomy controls.
- Prefer putting secondary actions inside the relevant scrolling content area rather than reserving permanent empty header space for them.
- Prefer dense, glanceable summaries over tall, form-like rows.
- Width and height should be biased toward the highest-value planning surfaces, especially blueprints and research.
- Items, notes, and low-frequency actions should compete for space only after the blueprint and split-planning surfaces are readable.

In practice this means the default response to "we need another control" should not be "give it a dedicated spacious region". The default response should be "how do we integrate it into the existing dense layout without stealing attention from the primary planning data?"

Undecided: Many blueprints are staged in that they include items from the previous blueprint in addition to the new entities. There needs to be some way to not double count the old entitities that were already build in a previous blueprint.

### Blueprint association and refresh model

Associating blueprints with splits is foundational to the usefulness of the planner, but Factorio does not expose a reliable global identity system for arbitrary player-created library blueprints that the mod can treat as a permanent canonical ID. The design should therefore use a **heuristic link model** rather than pretending that blueprint references are perfectly durable.

The intended player workflow is:

1. While editing a split, the player associates one or more blueprints with that split.
2. The plan stores enough metadata about each blueprint to find it again later.
3. The player continues to improve those real blueprints in their own blueprint library over time.
4. Later, from the plan editor, the player runs `Refresh Linked Blueprints`.
5. The mod searches the player's blueprint library and updates each linked blueprint reference when it finds a strong match.

This design avoids the worst workflow failure mode, where a speedrunner spends many hours refining blueprints and then has to rebuild the entire speedrun plan from scratch.

### Why this is heuristic instead of absolute

Blueprint names and blueprint book organization are meaningful to players, but they are not guaranteed unique. Books can be renamed, blueprints can be duplicated, and layouts can evolve over time. The architecture should embrace that reality and treat blueprint resolution as a best-effort matching pipeline with explicit failure states.

The mod should not claim:

- that blueprint names are globally unique
- that a linked blueprint always refreshes automatically
- that a renamed or duplicated blueprint can always be resolved without ambiguity

Instead, the mod should claim:

- blueprint symlinks can usually be refreshed from the player's library
- exact path-and-name matches are preferred
- ambiguous or missing matches are surfaced clearly to the player

### Stored blueprint symlink data

When a blueprint is associated with a split, the plan should store both a snapshot of the blueprint-derived planning data and a set of link hints used for future refresh.

Each blueprint symlink record should include, at minimum:

- `blueprint_name`
- `book_path_by_name`
- `book_local_index`
- `blueprint_fingerprint`
- `entity_summary`
- `tile_summary` if useful later
- any extracted planning data the split needs immediately, such as entity counts, item costs, and build-relevant metadata

The key design idea is that **blueprint name is the primary human-facing key**, while book path and content summaries are tie-breakers and recovery hints.

`book_path_by_name` should store the full named path through nested blueprint books, not just one parent book name. This is important because serious players often reuse book names like `Mall`, `Rails`, or `Science` in multiple places.

### Refresh matching pipeline

`Refresh Linked Blueprints` should resolve each blueprint symlink using a deterministic series of increasingly permissive searches:

1. Exact path match: same blueprint-book path by name and same blueprint name.
2. Same path unique-name match: same book path by name and exactly one blueprint with that name.
3. Global unique-name match: exactly one blueprint with that name anywhere in the player's library.
4. Fuzzy candidate match: choose from likely candidates only when content similarity is strong enough to justify it.
5. Otherwise mark the link unresolved.

This matching order preserves ergonomics without becoming reckless. The mod should be conservative about silently selecting among multiple candidates.

### Resolution states

Each blueprint symlink should surface a resolution state in the editor. The exact UI can evolve later, but the data model should assume states such as:

- `exact`
- `relocated`
- `fuzzy`
- `ambiguous`
- `missing`

These states should drive future UI decisions, error badges, and any batch refresh summary shown to the player.

### Fuzzy matching guidance

If fuzzy matching is implemented, it should be based primarily on blueprint content characteristics rather than edit distance on the blueprint name.

Preferred fuzzy signals:

- entity-count multiset
- tile-count summary
- preview icons if available
- bounding-box dimensions if they help

Name-based similarity can still be used as a secondary hint, but the architecture should not depend on text similarity alone. Players often keep the same route concept while making substantial layout edits, and content-based matching is more resilient than raw name matching.

Exact position-by-position layout matching should not be the first fuzzy strategy because it is too brittle for real blueprint evolution.

### Safety rules

The refresh system should follow a few non-negotiable safety rules:

- Never silently choose between multiple equally plausible candidates.
- Never discard the previous linked snapshot until a replacement has been resolved successfully.
- Always preserve enough prior metadata to let the user retry or manually relink later.
- Treat refresh as an explicit player action, not a background automatic mutation.

This keeps the tool trustworthy for speedrunners, who need predictable behavior more than cleverness.

### Product consequence

The architecture should treat linked blueprints as **refreshable references with stored snapshots**, not as perfectly durable pointers into the player's blueprint library.

That means:

- players do not need to keep duplicate working copies of every blueprint just for the mod
- players can continue refining their real library blueprints over time
- the plan can usually pick up those changes later through refresh
- edge cases will still exist, but they become visible resolution problems instead of silent data corruption

### 3) Event-snooping progress tracker

This component watches Factorio events and statistics and maintains the runtime state used by the split visualizer and predictor.

- Use per-surface force item production statistics for automated production deltas.
- Use craft, build, mine, and destroy events for hand crafting, placed entities, mined returns, and explicit losses.
- Maintain per-surface ledgers for production totals, manual-crafted totals, loose stock estimates, placed entities, and uncertainty state.
- Track placed entities separately from loose stock. They count toward build progress, but they are not next-split loose surplus unless mined back.
- Stay event-first in normal play. Do not rely on recurring reconciliation scans.
- If exact loose-stock accounting becomes impossible after destruction, mark the surface uncertain instead of inventing certainty.
- The first debug surface should be a hover popup on `Splits` showing item icon, placed count, loose stock estimate, and uncertainty status.

#### Known loose-stock limitations

- Destroyed container contents are not perfectly observable. `on_entity_died` tells us that an entity died, but it does not provide a full "all items that vanished from that entity's inventories" payload, so chest and machine contents can force the tracker into an uncertain state.
- Item production statistics are totals, not stock snapshots. `LuaForce.get_item_production_statistics(surface)` and `LuaFlowStatistics` tell us lifetime production and consumption for a surface, but they do not say where items are now or why they disappeared.
- There is no general event for arbitrary machine, chest, belt, or inserter inventory changes. Player inventories have dedicated events, but ordinary entity inventories do not, so the tracker cannot learn about every loose-stock change from one universal hook.
- Script or mod actions can bypass the player-style lifecycle. Script destruction is only visible when code raises `script_raised_destroy`, and `LuaEntity.destroy()` does not raise it unless requested. Script mining can also drop or destroy results depending on how it is called.
- Mapping a placed entity back to an item is not always unique. `LuaEntityPrototype.items_to_place_this` can contain multiple items, and the docs note that construction bots choose the first item in the list, so some prototypes are inherently ambiguous if different placeable items create the same entity.
- Any intentionally untracked carrier will be a known source of drift. The tracker can read many inventories and transport lines, but if a storage location is outside the first supported set, the mod should document it as unsupported instead of pretending the estimate is exact.

## Persistent plan storage and cross-save transfer

Speedrunners need to be able to design a plan in one save, then start a fresh run and load that same plan immediately. The preferred transport mechanism is a portable **blueprint book item** because it already travels across saves, fits normal player workflows, and is the most likely path to Steam Cloud synchronization without depending on any mod-managed external files.

### Requirements

- Plans must survive across saves without requiring external files.
- Each save should have exactly one active working plan in `storage`.
- Importing a plan into a fresh save should be explicit and cursor-driven.
- The storage format should be versioned so that future mod releases can migrate old plans.
- The in-save working copy of the plan should remain in `storage`; the portable copy is an explicit export artifact.
- The export format should be understandable enough that advanced users can manually inspect and occasionally edit it by hand.

### Recommended design: single active plan plus nested portable plan books

The mod should keep one editable plan in save-local `storage` and treat blueprint books as portable import/export artifacts.

The upper-left action button is the only entry point:

- If the player is not holding a valid Long Pole plan book, clicking it creates a new empty plan and opens the editor.
- If the player is holding a valid Long Pole plan book in the cursor, clicking it imports that plan and opens the editor.

The exported blueprint book should contain:

- The plan name in the top-level blueprint book label.
- Global plan metadata in the top-level blueprint book description.
- One child blueprint book per split.

The editor is not a multi-plan browser. It always edits the single active plan currently loaded in the save.

### Top-level plan book format

The top-level blueprint book is the exported run plan.

Top-level book rules:

- The label is the plan name.
- The order of child split books is the authoritative split order.
- The description is a small ASCII key/value document.

Current shape:

```text
format=long-pole-plan;version=1
plan_id=plan-42
visibility=references-only
default_surface=nauvis
```

This top-level description intentionally stays small and human-readable. It is not used to store the ordered split contents themselves; those live in the nested split books.

### Split book format

Each split is exported as its own child blueprint book inside the plan book.

Split book rules:

- The split book label is the split name.
- The order of child blueprint entries inside the split book is the authoritative linked-blueprint order.
- The split book description stores the split-local human-editable metadata.

Current shape:

```text
format=long-pole-split;version=1
surface=nauvis

--- Extra Items ---
transport-belt=200
iron-chest=3

--- Technologies to Research ---
automation
logistics

--- Notes ---
Feed gears before circuits.
```

Section rules:

- `surface` is preferred over `planet` because Space Age work can happen on non-planet surfaces such as space platforms.
- `--- Extra Items ---` contains `prototype-name=count` lines.
- `--- Technologies to Research ---` contains one technology name per line.
- `--- Notes ---` is always present at the end and may contain freeform lines.
- Repeated keys inside a section are not required for human-edited lists; the section structure is the primary grouping mechanism.

### Linked blueprint entry format

Each split book contains one child blueprint entry per linked blueprint.

The default export mode is a lightweight **reference-style** export:

- The child entry is still a blueprint item so the split book remains easy to reorder by hand in Factorio's UI.
- The child blueprint description stores the blueprint symlink metadata and planning fingerprint.
- The child blueprint does not need to contain the full original blueprint payload in the default export mode.

Current shape:

```text
format=long-pole-blueprint-link;version=1
link_mode=reference
library_root=player-blueprints
inside_book=Any% Openers
inside_book=Burner Starts
inside_book=Safe Variants
blueprint_name=Starter burner pair
blueprint_slot=2
blueprint_fingerprint=burner-mining-drill:2;stone-furnace:2
```

Notes on path encoding:

- Do not flatten nested book paths into one separator-delimited string.
- Use repeated `inside_book=` lines in order from outermost to innermost book.
- If the blueprint lives directly in the blueprint library root, omit `inside_book=` lines entirely.

This avoids separator-escaping problems when blueprint book names contain characters such as `/`.

### Reference exports versus copied exports

The storage model should explicitly distinguish between:

- **Reference export**: split books contain lightweight blueprint symlink entries with planning fingerprints.
- **Copied export**: split books contain full copied blueprints so the plan is self-contained and shareable with players who do not have the same blueprint library.

The current default format is reference export. A future option may enable copied exports without changing the surrounding book-of-books structure.

### Why description text is acceptable here

This design intentionally uses visible blueprint book and blueprint descriptions because:

- the descriptions remain fairly small and structured
- advanced users can read and manually edit them when the in-game UI is awkward
- the top-level order and nested-book structure carry much of the plan shape, so the textual payload per object stays modest

Opaque JSON blobs and multi-chunk carrier blueprints are therefore not the preferred long-term format for this design.

### Import workflow

The import workflow should be:

1. Player holds a Long Pole plan book in the cursor.
2. Player clicks the upper-left `Import Plan` action.
3. The mod validates the top-level plan book description.
4. The mod reads child split books in inventory order.
5. The mod reads each split book description plus its child blueprint-link entries.
6. The decoded plan replaces the save's working plan in `storage`.

The export workflow should be the inverse:

1. Player clicks `Save to New Book` in the editor.
2. The mod creates a portable plan blueprint book in the cursor.
3. The mod writes the plan description to the top-level book and creates one split book per split.
4. The mod writes split descriptions and linked blueprint entry descriptions into the nested books.
5. Saving is allowed when the cursor is empty, or when the cursor is already holding the active plan's previously exported Long Pole book.

### Save-local data versus portable data

Two copies of plan data are acceptable and intentional:

- `storage` holds the live editable active plan used by the current save.
- The blueprint book is a portable snapshot used for transfer, backup, and sharing.

The mod should not continuously rewrite portable book data on every edit. Export should be a deliberate action so that editing remains cheap and predictable.

### Fallbacks and compatibility

The architecture should support fallback import/export methods later, but they should be secondary:

- Export/import via blueprint string text.
- Export/import via `script-output` JSON for advanced users.
- Migration of old schema versions on import.

## Engineering approach

- Ensure the mod works as designed and the GUI is intuitive.
- Maintain Factorio performance for bases typical of speedrunning (not megabases).
- Provide tests that validate the mod’s logic without requiring Factorio to be launched.
