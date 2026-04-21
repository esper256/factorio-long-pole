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

The plan editor must be treated as a **dense information workspace**, not a spacious form UI. Speedrunners need to see many splits and many requirements at once, so packing efficiency is a default design goal rather than a later cleanup task.

Each split includes:

- a name
- a list of blueprints the player intends to build
- a list of additional items (beyond what the blueprints include)
- a list of technologies to research before proceeding to the next split

The editor also surfaces supporting information to help with planning decisions, such as:

- the raw resource cost of every entity combined in each blueprint
- the total entity count of each blueprint

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

- linked blueprints can usually be refreshed from the player's library
- exact path-and-name matches are preferred
- ambiguous or missing matches are surfaced clearly to the player

### Stored blueprint link data

When a blueprint is associated with a split, the plan should store both a snapshot of the blueprint-derived planning data and a set of link hints used for future refresh.

Each linked blueprint record should include, at minimum:

- `blueprint_name`
- `book_path_by_name`
- `book_local_index`
- `exported_blueprint_fingerprint`
- `entity_summary`
- `tile_summary` if useful later
- any extracted planning data the split needs immediately, such as entity counts, item costs, and build-relevant metadata

The key design idea is that **blueprint name is the primary human-facing key**, while book path and content summaries are tie-breakers and recovery hints.

`book_path_by_name` should store the full named path through nested blueprint books, not just one parent book name. This is important because serious players often reuse book names like `Mall`, `Rails`, or `Science` in multiple places.

### Refresh matching pipeline

`Refresh Linked Blueprints` should resolve each linked blueprint using a deterministic series of increasingly permissive searches:

1. Exact path match: same blueprint-book path by name and same blueprint name.
2. Same path unique-name match: same book path by name and exactly one blueprint with that name.
3. Global unique-name match: exactly one blueprint with that name anywhere in the player's library.
4. Fuzzy candidate match: choose from likely candidates only when content similarity is strong enough to justify it.
5. Otherwise mark the link unresolved.

This matching order preserves ergonomics without becoming reckless. The mod should be conservative about silently selecting among multiple candidates.

### Resolution states

Each linked blueprint should surface a resolution state in the editor. The exact UI can evolve later, but the data model should assume states such as:

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
- item-cost summary
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
- The child blueprint description stores the link metadata and planning fingerprint.
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
fingerprint=burner-mining-drill:2;stone-furnace:2
```

Notes on path encoding:

- Do not flatten nested book paths into one separator-delimited string.
- Use repeated `inside_book=` lines in order from outermost to innermost book.
- If the blueprint lives directly in the blueprint library root, omit `inside_book=` lines entirely.

This avoids separator-escaping problems when blueprint book names contain characters such as `/`.

### Reference exports versus copied exports

The storage model should explicitly distinguish between:

- **Reference export**: split books contain lightweight blueprint link entries with planning fingerprints.
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
